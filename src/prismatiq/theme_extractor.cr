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
    DEFAULT_CACHE_TTL     = 7 * 24 * 60 * 60
    DEFAULT_QUALITY       = 1000
    DEFAULT_HTTP_TIMEOUT  =   10
    DEFAULT_MAX_FILE_SIZE = 10_i64 * 1024 * 1024

    property skip_if_configured : String?
    property cache_ttl : Int32
    property quality : Int32
    property http_timeout : Int32
    property max_file_size : Int64

    def initialize
      @skip_if_configured = nil
      @cache_ttl = DEFAULT_CACHE_TTL
      @quality = DEFAULT_QUALITY
      @http_timeout = DEFAULT_HTTP_TIMEOUT
      @max_file_size = DEFAULT_MAX_FILE_SIZE
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

    # Extract a theme (background + text colors) from an image or URL.
    # @param source [String] File path or URL to the image
    # @param options [ThemeOptions] Configuration options (cache_ttl, quality, http_timeout, etc.)
    # @return [ThemeResult?] The extracted theme result, or nil if extraction fails
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

    # Validate and fix a theme JSON string, ensuring text colors meet contrast requirements.
    # @param theme_json [String] JSON string with "bg" and optional "text" keys
    # @param legacy_bg [String?] Fallback background color if not in JSON
    # @param legacy_text [String?] Fallback text color if not in JSON
    # @return [String?] Fixed theme JSON string, or nil if invalid
    def fix_theme(theme_json : String, legacy_bg : String? = nil, legacy_text : String? = nil) : String?
      bg_rgb, text_hash = parse_theme_json(theme_json)

      bg_rgb ||= parse_color_to_rgb(legacy_bg) if legacy_bg

      if text_hash.empty? && legacy_text
        text_hash["light"] = legacy_text
        text_hash["dark"] = legacy_text
      end

      return unless bg_rgb

      if text_hash.has_key?("light") && text_hash.has_key?("dark")
        light_ok = text_hash["light"]?.try { |_l| meets_contrast?(_l, bg_rgb) } || false
        dark_ok = text_hash["dark"]?.try { |_d| meets_contrast?(_d, bg_rgb) } || false

        if light_ok && dark_ok
          return ThemeResult.new(bg_rgb, text_hash["light"], text_hash["dark"]).to_json
        end
      end

      text_colors = find_compliant_text_colors(bg_rgb)
      ThemeResult.new(bg_rgb, text_colors[:light], text_colors[:dark]).to_json
    end

    private def parse_theme_json(theme_json : String) : Tuple(Array(Int32)?, Hash(String, String))
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

      {bg_rgb, text_hash}
    end

    def clear_cache
      @cache.clear
    end

    private def extract_bg_from_ico(path : String, options : ThemeOptions) : Array(Int32)?
      ico = ICOFile.from_path(path)
      return unless ico && ico.valid?
      extract_colors_from_pixels(ico.to_rgba, ico.width, ico.height, options)
    rescue Exception
      return
    end

    private def extract_bg_from_ico_buffer(data : Slice(UInt8), options : ThemeOptions) : Array(Int32)?
      ico = ICOFile.from_slice(data)
      return unless ico && ico.valid?
      extract_colors_from_pixels(ico.to_rgba, ico.width, ico.height, options)
    rescue Exception
      return
    end

    private def extract_bg_from_image(path : String, options : ThemeOptions) : Array(Int32)?
      # Handle SVG files separately since CrImage doesn't support them
      if path.downcase.ends_with?(".svg")
        svg_colors = SVGColorExtractor.extract_from_file(path)
        return unless svg_colors.ok?
        
        # Use the first extracted color as background candidate
        return unless svg_colors.value.size > 0
        first_color = svg_colors.value[0]
        return [first_color.r, first_color.g, first_color.b]
      end
      
      img = CrImage.read(path)
      return unless img

      w = img.bounds.width
      h = img.bounds.height
      return if w == 0 || h == 0

      rgba = CrImage::Pipeline.new(img).result
      return unless rgba

      extract_colors_from_pixels(rgba.pix, w.to_i32, h.to_i32, options)
    rescue Exception
      return
    end

    private def extract_bg_from_image_buffer(data : Slice(UInt8), options : ThemeOptions) : Array(Int32)?
      # Check if data appears to be SVG (starts with <svg or <?xml)
      if data.size > 0 && data[0] == '<'.ord
        svg_content = String.new(data)
        if svg_content.downcase.includes?("<svg")
          svg_colors = SVGColorExtractor.extract_colors(svg_content)
          return unless svg_colors.size > 0
          first_color = svg_colors[0]
          return [first_color.r, first_color.g, first_color.b]
        end
      end
      
      TempfileHelper.with_tempfile("prismatiq_theme_", data) do |tmp_path|
        extract_bg_from_image(tmp_path, options)
      end
    rescue Exception
      return
    end

    private def extract_colors_from_pixels(pixels, w, h, options : ThemeOptions) : Array(Int32)?
      extractor_opts = ColorExtractor::Options.new
      extractor_opts.sample_size = options.quality
      ColorExtractor.extract_from_buffer(pixels, w, h, extractor_opts)
    end

    private def fetch_url(url : String, options : ThemeOptions) : Slice(UInt8)?
      unless @config.rate_limit_allow?
        @config.debug_log "fetch_url: rate limited, please retry later"
        return
      end

      uri = URI.parse(url)

      unless {"http", "https"}.includes?(uri.scheme)
        @config.debug_log "fetch_url: rejected non-http(s) scheme: #{uri.scheme}"
        return
      end

      host = uri.host
      return unless host

      if @config.ssrf_protection?
        if allowlist_allows?(host)
          @config.debug_log "fetch_url: host '#{host}' allowed via allowlist"
        else
          ips = Utils::IPValidator.resolve_host(host)
          ips.each do |ip|
            if Utils::IPValidator.private_address?(ip)
              @config.debug_log "fetch_url: SSRF blocked - host=#{host} ip=#{ip.address} reason=private_address"
              return
            end
          end
        end
      end

      client = HTTP::Client.new(uri)
      client.read_timeout = options.http_timeout.seconds
      client.connect_timeout = options.http_timeout.seconds

      headers = HTTP::Headers{
        "User-Agent" => "PrismatIQ/#{VERSION}",
        "Accept"     => "image/*,*/*;q=0.8",
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

      host_lower = host.downcase
      allowlist.any? do |allowed|
        host_lower == allowed.downcase
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
        dark:  RGB.new(light_text[0], light_text[1], light_text[2]).to_hex,
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
          return
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
