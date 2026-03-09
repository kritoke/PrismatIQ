require "./thread_safe_cache"
require "./rgb"

module PrismatIQ
  struct ThemeInfo
    getter type : Symbol
    getter luminance : Float64
    getter perceived_brightness : Float64

    def initialize(@type : Symbol, @luminance : Float64, @perceived_brightness : Float64)
    end
  end

  class ThemeDetector
    @luminance_cache : ThreadSafeCache(String, Float64)
    @theme_cache : ThreadSafeCache(String, Symbol)

    def initialize
      @luminance_cache = ThreadSafeCache(String, Float64).new
      @theme_cache = ThreadSafeCache(String, Symbol).new
    end

    def detect_theme(color : RGB) : Symbol
      key = color.hex
      @theme_cache.get_or_compute(key) do
        luminance = relative_luminance(color)
        luminance < 0.5 ? :dark : :light
      end
    end

    def detect_theme_info(color : RGB) : ThemeInfo
      luminance = relative_luminance(color)
      brightness = perceived_brightness(color)
      type = luminance < 0.5 ? :dark : :light
      ThemeInfo.new(type, luminance, brightness)
    end

    def relative_luminance(rgb : RGB) : Float64
      key = rgb.hex
      @luminance_cache.get_or_compute(key) do
        r = rgb.r / 255.0
        g = rgb.g / 255.0
        b = rgb.b / 255.0

        r = r <= 0.03928 ? r / 12.92 : ((r + 0.055) / 1.055) ** 2.4
        g = g <= 0.03928 ? g / 12.92 : ((g + 0.055) / 1.055) ** 2.4
        b = b <= 0.03928 ? b / 12.92 : ((b + 0.055) / 1.055) ** 2.4

        0.2126 * r + 0.7152 * g + 0.0722 * b
      end
    end

    def perceived_brightness(rgb : RGB) : Float64
      (0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b) / 255.0
    end

    def is_dark?(color : RGB) : Bool
      detect_theme(color) == :dark
    end

    def is_light?(color : RGB) : Bool
      detect_theme(color) == :light
    end

    def suggest_foreground(background : RGB) : RGB
      if is_dark?(background)
        RGB.new(255, 255, 255) # White for dark backgrounds
      else
        RGB.new(0, 0, 0) # Black for light backgrounds
      end
    end

    def suggest_background(foreground : RGB) : RGB
      if is_dark?(foreground)
        RGB.new(255, 255, 255) # White background for dark foreground
      else
        RGB.new(0, 0, 0) # Black background for light foreground
      end
    end

    def analyze_palette(palette : Array(RGB)) : Hash(Symbol, Array(RGB))
      result = {:dark => [] of RGB, :light => [] of RGB}
      palette.each do |color|
        theme = detect_theme(color)
        result[theme] << color
      end
      result
    end

    def dominant_theme(palette : Array(RGB)) : Symbol
      return :light if palette.empty?
      
      themes = analyze_palette(palette)
      dark_count = themes[:dark].size
      light_count = themes[:light].size
      
      dark_count > light_count ? :dark : :light
    end

    def clear_cache : Nil
      @luminance_cache.clear
      @theme_cache.clear
    end

    def cache_stats : NamedTuple(luminance: Int32, theme: Int32)
      {
        luminance: @luminance_cache.size,
        theme: @theme_cache.size
      }
    end
  end
end
