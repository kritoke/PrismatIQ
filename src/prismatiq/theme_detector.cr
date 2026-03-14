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

  # Thread-safe theme detector with instance-based caching.
  #
  # This class detects whether a color scheme is light or dark based on
  # relative luminance calculations. Results are cached for performance.
  #
  # ## Thread Safety Guarantees
  #
  # - **Instance Isolation**: Each `ThemeDetector` instance has its own cache.
  #   Multiple threads can safely use different instances without coordination.
  # - **Internal Synchronization**: Caches use `ThreadSafeCache` with mutex synchronization.
  # - **No Global State**: No class variables or shared mutable state between instances.
  # - **Safe Concurrent Access**: Multiple fibers/threads can call methods on the same
  #   instance simultaneously without race conditions.
  #
  # ## Usage Patterns
  #
  # Create instances as needed - they can be safely shared across threads:
  #
  # ```
  # # Safe to share across multiple fibers
  # detector = ThemeDetector.new
  # spawn { detector.detect_theme(color1) }
  # spawn { detector.detect_theme(color2) }
  # ```
  #
  # ## Migration Note
  #
  # This replaces the deprecated module-level `PrismatIQ::Theme` methods which
  # were not thread-safe due to shared global state.
  # - Each instance has its own cache (no shared global state)
  # - Safe to share a single instance across fibers, or create per-fiber instances
  # - Caching uses `ThreadSafeCache` with mutex synchronization
  #
  # ### Example
  # ```
  # detector = ThemeDetector.new
  #
  # # These calls are thread-safe
  # theme = detector.detect_theme(color)
  # info = detector.detect_theme_info(color)
  #
  # # Clear cache when done (also thread-safe)
  # detector.clear_cache
  # ```
  class ThemeDetector
    @luminance_cache : ThreadSafeCache(Tuple(Int32, Int32, Int32), Float64)
    @theme_cache : ThreadSafeCache(Tuple(Int32, Int32, Int32), Symbol)

    def initialize
      @luminance_cache = ThreadSafeCache(Tuple(Int32, Int32, Int32), Float64).new
      @theme_cache = ThreadSafeCache(Tuple(Int32, Int32, Int32), Symbol).new
    end

    def detect_theme(color : RGB) : Symbol
      key = {color.r, color.g, color.b}
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
      key = {rgb.r, rgb.g, rgb.b}
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

    def dark?(color : RGB) : Bool
      detect_theme(color) == :dark
    end

    def light?(color : RGB) : Bool
      detect_theme(color) == :light
    end

    def suggest_foreground(background : RGB) : RGB
      if dark?(background)
        RGB.new(255, 255, 255) # White for dark backgrounds
      else
        RGB.new(0, 0, 0) # Black for light backgrounds
      end
    end

    def analyze_theme(background : RGB) : ThemeInfo
      lum = relative_luminance(background)
      perceived = perceived_brightness(background)
      type = detect_theme(background)
      ThemeInfo.new(type, lum, perceived)
    end

    def suggest_text_palette(background : RGB, level : WCAGLevel = WCAGLevel::AA) : TextColorPalette
      theme_type = detect_theme(background)

      primary = AccessibilityCalculator.new.recommend_text_color(background, level, large_text: false)

      if theme_type == :dark
        secondary_raw = AccessibilityCalculator.new.lighten(primary, 0.3)
        accent_raw = RGB.new(
          (primary.r * 0.8 + 100).to_i.clamp(0, 255),
          (primary.g * 0.8 + 150).to_i.clamp(0, 255),
          (primary.b * 0.8 + 255).to_i.clamp(0, 255)
        )
      else
        secondary_raw = AccessibilityCalculator.new.darken(primary, 0.3)
        accent_raw = RGB.new(
          (primary.r * 0.6).to_i.clamp(0, 255),
          (primary.g * 0.6 + 50).to_i.clamp(0, 255),
          (primary.b * 0.6 + 150).to_i.clamp(0, 255)
        )
      end

      secondary_adjusted = AccessibilityCalculator.new.find_nearest_compliant(secondary_raw, background, level, large_text: true) || secondary_raw
      accent_adjusted = AccessibilityCalculator.new.find_nearest_compliant(accent_raw, background, level, large_text: true) || accent_raw

      TextColorPalette.new(primary, secondary_adjusted, accent_adjusted, background, theme_type)
    end

    def suggest_background(foreground : RGB) : RGB
      if dark?(foreground)
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
        theme:     @theme_cache.size,
      }
    end
  end
end
