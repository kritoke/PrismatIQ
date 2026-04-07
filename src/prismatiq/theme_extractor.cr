require "http/client"
require "uri"
require "socket"
require "openssl"
require "./thread_safe_cache"
require "./theme_result"
require "./rgb"
require "./utils/ip_validator"
require "./errors"
require "./accessibility_calculator"
require "./constants"

module PrismatIQ
  class ThemeExtractionError < Exception
  end

  struct ThemeOptions
    DEFAULT_QUALITY       = 1000
    DEFAULT_HTTP_TIMEOUT  =   10
    DEFAULT_MAX_FILE_SIZE = 10_i64 * 1024 * 1024

    property skip_if_configured : String?
    property quality : Int32
    property http_timeout : Int32
    property max_file_size : Int64

    def initialize
      @skip_if_configured = nil
      @quality = DEFAULT_QUALITY
      @http_timeout = DEFAULT_HTTP_TIMEOUT
      @max_file_size = DEFAULT_MAX_FILE_SIZE
    end
  end

  class ThemeExtractor
    @cache : ThreadSafeCache(String, ThemeResult)
    @theme_detector : ThemeDetector
    @accessibility : AccessibilityCalculator
    @config : Config

    def initialize(@config : Config = Config.default)
      @cache = ThreadSafeCache(String, ThemeResult).new(max_entries: 1000)
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
      elsif @config.debug_log?
        @config.log_debug "extract: failed to extract theme from '#{source}'"
      end

      result
    end

    def extract_from_file(path : String, options : ThemeOptions = ThemeOptions.new) : ThemeResult?
      return unless File.exists?(path)

      bg_rgb = if path.downcase.ends_with?(".ico")
                  extract_ico_bg(path, options)
                else
                  extract_image_bg(path, options)
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
                 extract_ico_buffer_bg(data, options)
               else
                 extract_buffer_bg(data, options)
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

      bg_rgb ||= parse_to_rgb(legacy_bg) if legacy_bg

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

      text_colors = find_text_colors(bg_rgb)
      ThemeResult.new(bg_rgb, text_colors[:light].to_hex, text_colors[:dark].to_hex).to_json
    end

    private def parse_theme_json(theme_json : String) : Tuple(Array(Int32)?, Hash(String, String))
      bg_rgb = nil
      text_hash = {} of String => String

      begin
        parsed = JSON.parse(theme_json)
        bg_val = parsed["bg"]?.try(&.as_s) || parsed["background"]?.try(&.as_s)
        bg_rgb = parse_to_rgb(bg_val) if bg_val

        if txt = parsed["text"]?
          if txt.is_a?(Hash)
            txt.as_h.each do |k, v|
              text_hash[k.to_s] = v.as_s
            end
          end
        end
      rescue ex : JSON::ParseException | TypeCastError
        @config.log_debug "fix_theme: JSON parse error (#{ex.class.name}): #{ex.message}"
      end

      {bg_rgb, text_hash}
    end

    def clear_cache
      @cache.clear
    end

    private def extract_ico_bg(path : String, options : ThemeOptions) : Array(Int32)?
      ico = ICOFile.from_path(path, @config)
      return unless ico && ico.valid?
      extract_pixel_colors(ico.to_rgba, ico.width, ico.height, options)
    rescue ex : Exception
      @config.log_debug "extract_ico_bg: #{ex.class}: #{ex.message}"
      return
    end

    private def extract_ico_buffer_bg(data : Slice(UInt8), options : ThemeOptions) : Array(Int32)?
      ico = ICOFile.from_slice(data, @config)
      return unless ico && ico.valid?
      extract_pixel_colors(ico.to_rgba, ico.width, ico.height, options)
    rescue ex : Exception
      @config.log_debug "extract_ico_buffer_bg: #{ex.class}: #{ex.message}"
      return
    end

    private def extract_image_bg(path : String, options : ThemeOptions) : Array(Int32)?
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

      extract_pixel_colors(rgba.pix, w.to_i32, h.to_i32, options)
    rescue ex : Exception
      @config.log_debug "extract_image_bg: #{ex.class}: #{ex.message}"
      return
    end

    private def extract_buffer_bg(data : Slice(UInt8), options : ThemeOptions) : Array(Int32)?
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
        extract_image_bg(tmp_path, options)
      end
    rescue ex : Exception
      @config.log_debug "extract_buffer_bg: #{ex.class}: #{ex.message}"
      return
    end

    private def extract_pixel_colors(pixels, w, h, options : ThemeOptions) : Array(Int32)?
      extractor_opts = ColorExtractor::Options.new
      extractor_opts.sample_size = options.quality
      ColorExtractor.extract_from_buffer(pixels, w, h, extractor_opts)
    end

    private def fetch_url(url : String, options : ThemeOptions) : Slice(UInt8)?
      unless @config.rate_limit_allow?
        @config.log_debug "fetch_url: rate limited, please retry later"
        return
      end

      uri = URI.parse(url)

      unless {"http", "https"}.includes?(uri.scheme)
        @config.log_debug "fetch_url: rejected non-http(s) scheme: #{uri.scheme}"
        return
      end

      host = uri.host
      return unless host

      port = uri.port || (uri.scheme == "https" ? 443 : 80)
      use_tls = uri.scheme == "https"

      validated_ip : Socket::IPAddress? = nil

      if @config.ssrf_protection? && !allowlist_allows?(host)
        resolved_ips = Utils::IPValidator.resolve_host(host)
        if resolved_ips.empty?
          @config.log_debug "fetch_url: DNS resolution failed for '#{host}'"
          return
        end

        resolved_ips.each do |ip|
          if Utils::IPValidator.private_address?(ip)
            @config.log_debug "fetch_url: SSRF blocked - host=#{host} ip=#{ip.address} reason=private_address"
            return
          end
        end

        validated_ip = resolved_ips.first
      end

      client : HTTP::Client? = nil
      begin
        if validated_ip
          client = connect_to_ip(validated_ip, host, port, use_tls)
        else
          client = HTTP::Client.new(host, port, tls: use_tls)
        end

        client.read_timeout = options.http_timeout.seconds
        client.connect_timeout = options.http_timeout.seconds

        default_port = use_tls ? 443 : 80
        host_value = port == default_port ? host : "#{host}:#{port}"

        headers = HTTP::Headers{
          "User-Agent" => "PrismatIQ/#{Version::VERSION}",
          "Accept"     => "image/*,*/*;q=0.8",
          "Host"       => host_value,
        }

        response = client.get(uri.request_target, headers: headers)

        return unless response.status_code == 200

        content_type = response.headers["Content-Type"]?
        if content_type && !content_type.starts_with?("image/")
          @config.log_debug "fetch_url: rejected non-image content-type: #{content_type}"
          return
        end

        content_length = response.headers["Content-Length"]?
        if content_length
          begin
            length = content_length.to_i64
            if length > options.max_file_size
              @config.log_debug "fetch_url: rejected due to Content-Length: #{length}"
              return
            end
          rescue ex : ArgumentError
          end
        end

        body = response.body

        return if body.size > options.max_file_size
        body.to_slice
      rescue ex : Exception
        @config.log_debug "fetch_url: exception #{ex.class.name}: #{ex.message}"
        nil
      ensure
        client.try(&.close)
      end
    end

    private def connect_to_ip(ip : Socket::IPAddress, original_host : String, port : Int32, use_tls : Bool) : HTTP::Client
      tcp = TCPSocket.new(ip.address, port)
      io : IO = tcp

      if use_tls
        io = OpenSSL::SSL::Socket::Client.new(tcp, hostname: original_host)
      end

      HTTP::Client.new(io, original_host)
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
      text_colors = find_text_colors(bg_rgb)
      ThemeResult.new(bg_rgb, text_colors[:light].to_hex, text_colors[:dark].to_hex)
    end

    private def find_text_colors(bg_rgb : Array(Int32)) : NamedTuple(light: RGB, dark: RGB)
      bg = RGB.new(bg_rgb[0], bg_rgb[1], bg_rgb[2])

      {
        light: find_light_contrast_text(bg),
        dark:  find_dark_contrast_text(bg),
      }
    end

    private def find_light_contrast_text(bg : RGB) : RGB
      (0..255).step(Constants::ThemeExtraction::GRAY_STEP) do |val|
        candidate = RGB.new(val, val, val)
        return candidate if @accessibility.contrast_ratio(candidate, bg) >= Constants::WCAG::CONTRAST_RATIO_AA
      end
      RGB.new(Constants::ThemeExtraction::DARK_TEXT_FALLBACK[0], Constants::ThemeExtraction::DARK_TEXT_FALLBACK[1], Constants::ThemeExtraction::DARK_TEXT_FALLBACK[2])
    end

    private def find_dark_contrast_text(bg : RGB) : RGB
      val = 255
      while val >= 0
        candidate = RGB.new(val, val, val)
        return candidate if @accessibility.contrast_ratio(candidate, bg) >= Constants::WCAG::CONTRAST_RATIO_AA
        val -= Constants::ThemeExtraction::GRAY_STEP
      end
      RGB.new(Constants::ThemeExtraction::LIGHT_TEXT_FALLBACK[0], Constants::ThemeExtraction::LIGHT_TEXT_FALLBACK[1], Constants::ThemeExtraction::LIGHT_TEXT_FALLBACK[2])
    end

    private def parse_to_rgb(color_str : String?) : Array(Int32)?
      return unless color_str
      s = color_str.strip
      begin
        if s.starts_with?("rgb(") || s.starts_with?("rgba(")
          rgb = RGB.from_rgb_string(s)
          return [rgb.r, rgb.g, rgb.b]
        end
        if s.starts_with?("#")
          rgb = RGB.from_hex(s)
          return [rgb.r, rgb.g, rgb.b]
        end
      rescue ValidationError
      end
      nil
    end

    private def meets_contrast?(text_color : String, bg_rgb : Array(Int32)) : Bool
      text_rgb = parse_to_rgb(text_color)
      return false unless text_rgb

      text = RGB.new(text_rgb[0], text_rgb[1], text_rgb[2])
      bg = RGB.new(bg_rgb[0], bg_rgb[1], bg_rgb[2])

      @accessibility.contrast_ratio(text, bg) >= Constants::WCAG::CONTRAST_RATIO_AA
    end
  end
end
