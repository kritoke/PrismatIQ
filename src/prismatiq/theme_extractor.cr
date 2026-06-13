require "uri"
require "./thread_safe_cache"
require "./theme_result"
require "./rgb"
require "./utils/validation"
require "./errors"
require "./accessibility_calculator"
require "./constants"
require "./url_fetcher"

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

  # Orchestrator for theme extraction from various sources.
  #
  # Delegates HTTP fetching to URLFetcher (SSRF, rate limiting, streaming)
  # and image parsing to focused extractors (SVGColorExtractor, ICOFile, CrImage).
  # Owns caching and theme result construction only.
  class ThemeExtractor
    @cache : ThreadSafeCache(String, ThemeResult)
    @theme_detector : ThemeDetector
    @accessibility : AccessibilityCalculator
    @config : Config
    @url_fetcher : URLFetcher

    def initialize(@config : Config = Config.default)
      @cache = ThreadSafeCache(String, ThemeResult).new(max_entries: 1000)
      @theme_detector = ThemeDetector.new
      @accessibility = AccessibilityCalculator.new
      @url_fetcher = URLFetcher.new(@config)
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
      elsif @config.debug_log?
        @config.log_debug "extract: failed to extract theme from '#{source}'"
      end

      result
    end

    def extract_from_file(path : String, options : ThemeOptions = ThemeOptions.new) : ThemeResult?
      validation = Utils::Validation.validate_file_path(path)
      return unless validation.ok?
      safe_path = validation.value

      bg_rgb = if safe_path.downcase.ends_with?(".ico")
                 extract_ico_bg(safe_path, options)
               else
                 extract_image_bg(safe_path, options)
               end

      return unless bg_rgb

      build_theme_result(bg_rgb)
    end

    def extract_from_url(url : String, options : ThemeOptions = ThemeOptions.new) : ThemeResult?
      uri = URI.parse(url)
      return unless uri.scheme && uri.host
      return unless {"http", "https"}.includes?(uri.scheme)

      data = @url_fetcher.fetch(uri, options)
      return unless data

      bg_rgb = if url.downcase.ends_with?(".ico")
                 extract_ico_buffer_bg(data, options)
               else
                 extract_buffer_bg(data, options)
               end

      return unless bg_rgb

      build_theme_result(bg_rgb)
    end

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

    def clear_cache
      @cache.clear
    end

    # --- Private: Image extraction ---

    private def extract_ico_colors(ico : ICOFile?, options : ThemeOptions) : RGB?
      return unless ico && ico.valid?
      extract_pixel_colors(ico.to_rgba, ico.width, ico.height, options)
    rescue ex : IO::Error | ArgumentError | IndexError | OverflowError | ICOFile::ICOError
      @config.log_debug "extract_ico_colors: #{ex.class}: #{ex.message}"
      nil
    end

    private def extract_ico_bg(path : String, options : ThemeOptions) : RGB?
      extract_ico_colors(ICOFile.from_path(path, @config), options)
    end

    private def extract_ico_buffer_bg(data : Slice(UInt8), options : ThemeOptions) : RGB?
      extract_ico_colors(ICOFile.from_slice(data, @config), options)
    end

    private def extract_image_bg(path : String, options : ThemeOptions) : RGB?
      # Try SVG first (unified detection via extension)
      svg_bg = SVGColorExtractor.extract_bg_from_file(path, options)
      return svg_bg if svg_bg

      img = CrImage.read(path)
      return unless img

      w = img.bounds.width.to_i32
      h = img.bounds.height.to_i32
      return if w == 0 || h == 0
      return if w > @config.max_image_width || h > @config.max_image_height

      rgba = CrImage::Pipeline.new(img).result
      return unless rgba

      extract_pixel_colors(rgba.pix, w, h, options)
    rescue ex : Exception
      @config.log_debug "extract_image_bg: #{ex.class}: #{ex.message}"
      return
    end

    private def extract_buffer_bg(data : Slice(UInt8), options : ThemeOptions) : RGB?
      # Try SVG first (unified detection via content sniffing)
      svg_bg = SVGColorExtractor.extract_bg_from_buffer(data)
      return svg_bg if svg_bg

      TempfileHelper.with_tempfile("prismatiq_theme_", data) do |tmp_path|
        extract_image_bg(tmp_path, options)
      end
    rescue ex : IO::Error | ArgumentError
      @config.log_debug "extract_buffer_bg: #{ex.class}: #{ex.message}"
      return
    end

    private def extract_pixel_colors(pixels, w, h, options : ThemeOptions) : RGB?
      extractor_opts = Options.new(quality: options.quality)
      result = ColorExtractor.extract_from_buffer(pixels, w, h, extractor_opts)
      result.try(&.first?)
    end

    # --- Private: Theme construction ---

    private def build_theme_result(bg_rgb : RGB) : ThemeResult
      text_colors = find_text_colors(bg_rgb)
      ThemeResult.new(bg_rgb, text_colors[:light].to_hex, text_colors[:dark].to_hex)
    end

    private def find_text_colors(bg_rgb : RGB) : NamedTuple(light: RGB, dark: RGB)
      {
        light: find_compliant_text(bg_rgb, ascending: true),
        dark:  find_compliant_text(bg_rgb, ascending: false),
      }
    end

    # Scans gray values to find the first that meets WCAG AA contrast.
    # ascending=true → darkest compliant (light text on dark bg).
    # ascending=false → lightest compliant (dark text on light bg).
    private def find_compliant_text(bg : RGB, ascending : Bool) : RGB
      if ascending
        fallback = RGB.new(Constants::ThemeExtraction::DARK_TEXT_FALLBACK[0], Constants::ThemeExtraction::DARK_TEXT_FALLBACK[1], Constants::ThemeExtraction::DARK_TEXT_FALLBACK[2])
      else
        fallback = RGB.new(Constants::ThemeExtraction::LIGHT_TEXT_FALLBACK[0], Constants::ThemeExtraction::LIGHT_TEXT_FALLBACK[1], Constants::ThemeExtraction::LIGHT_TEXT_FALLBACK[2])
      end

      step = Constants::ThemeExtraction::GRAY_STEP
      val = ascending ? 0 : 255

      while ascending ? (val <= 255) : (val >= 0)
        candidate = RGB.new(val, val, val)
        return candidate if @accessibility.contrast_ratio(candidate, bg) >= Constants::WCAG::CONTRAST_RATIO_AA
        val += ascending ? step : -step
      end
      fallback
    end

    # --- Private: JSON parsing ---

    private def parse_theme_json(theme_json : String) : Tuple(RGB?, Hash(String, String))
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

    private def parse_to_rgb(color_str : String?) : RGB?
      return unless color_str
      s = color_str.strip
      RGB.from_color_string(s)
    rescue ValidationError
      nil
    end

    private def meets_contrast?(text_color : String, bg_rgb : RGB) : Bool
      text_rgb = parse_to_rgb(text_color)
      return false unless text_rgb

      @accessibility.contrast_ratio(text_rgb, bg_rgb) >= Constants::WCAG::CONTRAST_RATIO_AA
    end
  end
end
