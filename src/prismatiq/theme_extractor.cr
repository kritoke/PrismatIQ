require "http/client"
require "uri"
require "./thread_safe_cache"
require "./theme_result"
require "./rgb"
require "./utils/ip_validator"
require "./errors"

module PrismatIQ
  class ThemeExtractionError < Exception
  end

  struct ThemeOptions
    property skip_if_configured : String?
    property cache_ttl : Int32
    property quality : Int32
    property http_timeout : Int32
    property max_file_size : Int64

    def initialize
      @skip_if_configured = nil
      @cache_ttl = 7 * 24 * 60 * 60
      @quality = 1000
      @http_timeout = 10
      @max_file_size = 10_i64 * 1024 * 1024
    end
  end

  class ThemeExtractor
    @@mutex = Mutex.new
    @@instance : ThemeExtractor?

    def self.instance : ThemeExtractor
      @@mutex.synchronize do
        @@instance ||= new
      end
    end

    @cache : ThreadSafeCache(String, ThemeResult)
    @theme_detector : ThemeDetector
    @accessibility : AccessibilityCalculator
    @config : Config

    def initialize(@config : Config = Config.default)
      @cache = ThreadSafeCache(String, ThemeResult).new
      @theme_detector = ThemeDetector.new
      @accessibility = AccessibilityCalculator.new
    end

    def extract(source : String, options : ThemeOptions = ThemeOptions.new) : ThemeResult?
      skip_val = options.skip_if_configured
      return if skip_val && !skip_val.empty?

      cache_key = source
      cached = @cache[cache_key]
      return cached if cached

      result = if source.starts_with?("http://") || source.starts_with?("https://")
        extract_from_url(source, options)
      else
        extract_from_file(source, options)
      end

      if result
        @cache[cache_key] = result
      end

      result
    end

    def extract_from_file(path : String, options : ThemeOptions = ThemeOptions.new) : ThemeResult?
      return unless File.exists?(path)

      bg_rgb = if path.downcase.ends_with?(".ico")
        extract_bg_from_ico(path, options)
      else
        extract_bg_from_image(path, options)
      end

      return unless bg_rgb

      build_theme_result(bg_rgb)
    end

    def extract_from_url(url : String, options : ThemeOptions = ThemeOptions.new) : ThemeResult?
      uri = URI.parse(url)
      return unless uri.scheme && uri.host

      data = fetch_url(url, options)
      return unless data

      bg_rgb = if url.downcase.ends_with?(".ico")
        extract_bg_from_ico_buffer(data, options)
      else
        extract_bg_from_image_buffer(data, options)
      end

      return unless bg_rgb

      build_theme_result(bg_rgb)
    end

    def fix_theme(theme_json : String, legacy_bg : String? = nil, legacy_text : String? = nil) : String?
      bg_rgb = nil
      text_hash = {} of String => String

      begin
        parsed = JSON.parse(theme_json)
        bg_val = parsed["bg"]?.try(&.as_s) || parsed["background"]?.try(&.as_s)
        bg_rgb = parse_color_to_rgb(bg_val) if bg_val

        if txt = parsed["text"]?
          if txt.is_a?(Hash)
            txt.as_h.each do |k, v|
              text_hash[k.to_s] = v.as_s
            end
          end
        end
      rescue ex : Exception
        @config.debug_log "fix_theme: JSON.parse error (#{ex.class.name}): #{ex.message}"
      end

      bg_rgb ||= parse_color_to_rgb(legacy_bg) if legacy_bg

      if text_hash.empty? && legacy_text
        text_hash["light"] = legacy_text
        text_hash["dark"] = legacy_text
      end

      return unless bg_rgb

      if text_hash.has_key?("light") && text_hash.has_key?("dark")
        light_ok = text_hash["light"]?.try { |l| meets_contrast?(l, bg_rgb) } || false
        dark_ok = text_hash["dark"]?.try { |d| meets_contrast?(d, bg_rgb) } || false

        if light_ok && dark_ok
          return ThemeResult.new(bg_rgb, text_hash["light"], text_hash["dark"]).to_json
        end
      end

      text_colors = find_compliant_text_colors(bg_rgb)
      ThemeResult.new(bg_rgb, text_colors[:light], text_colors[:dark]).to_json
    end

    def clear_cache
      @cache.clear
    end

    private def extract_bg_from_ico(path : String, options : ThemeOptions) : Array(Int32)?
      ico = ICOFile.from_path(path)
      return unless ico && ico.valid?

      pixels = ico.to_rgba
      w = ico.width
      h = ico.height

      extractor_opts = ColorExtractor::Options.new
      extractor_opts.sample_size = options.quality
      ColorExtractor.extract_from_buffer(pixels, w, h, extractor_opts)
    end

    private def extract_bg_from_ico_buffer(data : Slice(UInt8), options : ThemeOptions) : Array(Int32)?
      ico = ICOFile.from_slice(data)
      return unless ico && ico.valid?

      pixels = ico.to_rgba
      w = ico.width
      h = ico.height

      extractor_opts = ColorExtractor::Options.new
      extractor_opts.sample_size = options.quality
      ColorExtractor.extract_from_buffer(pixels, w, h, extractor_opts)
    end

    private def extract_bg_from_image(path : String, options : ThemeOptions) : Array(Int32)?
      img = CrImage.read(path)
      return unless img

      w = img.bounds.width
      h = img.bounds.height
      return if w == 0 || h == 0

      rgba = CrImage::Pipeline.new(img).result
      return unless rgba

      pixels = rgba.pix

      extractor_opts = ColorExtractor::Options.new
      extractor_opts.sample_size = options.quality
      ColorExtractor.extract_from_buffer(pixels, w.to_i32, h.to_i32, extractor_opts)
    end

    private def extract_bg_from_image_buffer(data : Slice(UInt8), options : ThemeOptions) : Array(Int32)?
      TempfileHelper.with_tempfile("prismatiq_theme_", data) do |tmp_path|
        extract_bg_from_image(tmp_path, options)
      end
    end

    private def fetch_url(url : String, options : ThemeOptions) : Slice(UInt8)?
      uri = URI.parse(url)

      unless {"http", "https"}.includes?(uri.scheme)
        @config.debug_log "fetch_url: rejected non-http(s) scheme: #{uri.scheme}"
        return nil
      end

      host = uri.host
      return nil unless host

      if @config.ssrf_protection?
        if allowlist_allows?(host)
          @config.debug_log "fetch_url: host '#{host}' allowed via allowlist"
        else
          ips = Utils::IPValidator.resolve_host(host)
          ips.each do |ip|
            if Utils::IPValidator.private_address?(ip)
              @config.debug_log "fetch_url: SSRF blocked - host=#{host} ip=#{ip.address} reason=private_address"
              return nil
            end
          end
        end
      end

      client = HTTP::Client.new(uri)
      client.read_timeout = options.http_timeout.seconds
      client.connect_timeout = options.http_timeout.seconds

      headers = HTTP::Headers{
        "User-Agent" => "PrismatIQ/#{VERSION}",
        "Accept" => "image/*,*/*;q=0.8"
      }

      response = client.get(uri.request_target, headers: headers)

      return unless response.status_code == 200
      return if response.body.size > options.max_file_size

      response.body.to_slice
    rescue ex : Exception
      @config.debug_log "fetch_url: exception #{ex.class.name}: #{ex.message}"
      nil
    end

    private def allowlist_allows?(host : String) : Bool
      allowlist = @config.ssrf_allowlist
      return false unless allowlist

      allowlist.any? do |allowed|
        host == allowed || host.ends_with?(".#{allowed}")
      end
    end

    private def build_theme_result(bg_rgb : Array(Int32)) : ThemeResult
      text_colors = find_compliant_text_colors(bg_rgb)
      ThemeResult.new(bg_rgb, text_colors[:light], text_colors[:dark])
    end

    private def find_compliant_text_colors(bg_rgb : Array(Int32)) : NamedTuple(light: String, dark: String)
      bg = RGB.new(bg_rgb[0], bg_rgb[1], bg_rgb[2])

      dark_text = find_compliant_dark_text(bg)
      light_text = find_compliant_light_text(bg)

      {
        light: RGB.new(dark_text[0], dark_text[1], dark_text[2]).to_hex,
        dark: RGB.new(light_text[0], light_text[1], light_text[2]).to_hex
      }
    end

    private def find_compliant_dark_text(bg : RGB) : Array(Int32)
      (0..255).step(5) do |val|
        candidate = RGB.new(val, val, val)
        if @accessibility.contrast_ratio(candidate, bg) >= 4.5
          return [val, val, val]
        end
      end
      [17, 17, 17]
    end

    private def find_compliant_light_text(bg : RGB) : Array(Int32)
      val = 255
      while val >= 0
        candidate = RGB.new(val, val, val)
        if @accessibility.contrast_ratio(candidate, bg) >= 4.5
          return [val, val, val]
        end
        val -= 5
      end
      [238, 238, 238]
    end

    private def parse_color_to_rgb(color_str : String?) : Array(Int32)?
      return unless color_str

      s = color_str.strip

      if s.starts_with?("rgb(")
        s = s.sub("rgb(", "").sub(")", "").gsub(" ", "")
        parts = s.split(",")
        return unless parts.size == 3
        r = parts[0].to_i32?
        g = parts[1].to_i32?
        b = parts[2].to_i32?
        return unless r && g && b
        return [r, g, b]
      end

      if s.starts_with?("#")
        s = s[1..-1] if s.size == 7
        return unless s.size == 6
        begin
          r = s[0..1].to_i(16)
          g = s[2..3].to_i(16)
          b = s[4..5].to_i(16)
          return [r, g, b]
        rescue
          return nil
        end
      end

      nil
    end

    private def meets_contrast?(text_color : String, bg_rgb : Array(Int32)) : Bool
      text_rgb = parse_color_to_rgb(text_color)
      return false unless text_rgb

      text = RGB.new(text_rgb[0], text_rgb[1], text_rgb[2])
      bg = RGB.new(bg_rgb[0], bg_rgb[1], bg_rgb[2])

      @accessibility.contrast_ratio(text, bg) >= 4.5
    end
  end
end
