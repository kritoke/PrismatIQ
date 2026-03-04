require "concurrent"

module PrismatIQ
  struct ThemeInfo
    getter type : Symbol
    getter luminance : Float64
    getter perceived_brightness : Float64

    def initialize(@type : Symbol, @luminance : Float64, @perceived_brightness : Float64)
    end
  end

  struct TextColorPalette
    getter primary : RGB
    getter secondary : RGB
    getter accent : RGB
    getter background : RGB
    getter theme_type : Symbol

    def initialize(@primary : RGB, @secondary : RGB, @accent : RGB, @background : RGB, @theme_type : Symbol)
    end
  end

  struct ColorPair
    getter background : RGB
    getter text : RGB
    getter contrast_ratio : Float64
    getter compliance_level : WCAGLevel

    def initialize(@background : RGB, @text : RGB, @contrast_ratio : Float64, @compliance_level : WCAGLevel)
    end
  end

  struct DualThemePalette
    getter light : TextColorPalette
    getter dark : TextColorPalette

    def initialize(@light : TextColorPalette, @dark : TextColorPalette)
    end
  end

  module Theme
    LUMINANCE_THRESHOLD = 0.5

    @@theme_cache = Hash(Tuple(Int32, Int32, Int32), Symbol).new
    @@theme_mutex = Mutex.new

    def self.clear_cache : Nil
      @@theme_mutex.synchronize do
        @@theme_cache.clear
      end
    end

    def self.detect_theme(background : RGB) : Symbol
      key = {background.r, background.g, background.b}
      
      if cached = @@theme_cache[key]?
        return cached
      end
      
      @@theme_mutex.synchronize do
        @@theme_cache[key] ||= begin
          lum = Accessibility.relative_luminance(background)
          lum > LUMINANCE_THRESHOLD ? :light : :dark
        end
      end
      @@theme_cache[key].not_nil!
    end

    def self.analyze_theme(background : RGB) : ThemeInfo
      lum = Accessibility.relative_luminance(background)
      perceived = (0.299 * background.r + 0.587 * background.g + 0.114 * background.b) / 255.0
      type = lum > LUMINANCE_THRESHOLD ? :light : :dark
      ThemeInfo.new(type, lum, perceived)
    end

    def self.suggest_text_palette(background : RGB, level : WCAGLevel = WCAGLevel::AA) : TextColorPalette
      theme_type = detect_theme(background)
      
      primary = Accessibility.recommend_text_color(background, level, large_text: false)
      
      if theme_type == :dark
        secondary_raw = Accessibility.lighten(primary, 0.3)
        accent_raw = RGB.new(
          (primary.r * 0.8 + 100).to_i.clamp(0, 255),
          (primary.g * 0.8 + 150).to_i.clamp(0, 255),
          (primary.b * 0.8 + 255).to_i.clamp(0, 255)
        )
      else
        secondary_raw = Accessibility.darken(primary, 0.3)
        accent_raw = RGB.new(
          (primary.r * 0.6).to_i.clamp(0, 255),
          (primary.g * 0.6 + 50).to_i.clamp(0, 255),
          (primary.b * 0.6 + 150).to_i.clamp(0, 255)
        )
      end

      secondary_adjusted = Accessibility.find_nearest_compliant(secondary_raw, background, level, large_text: true) || secondary_raw
      accent_adjusted = Accessibility.find_nearest_compliant(accent_raw, background, level, large_text: true) || accent_raw

      TextColorPalette.new(primary, secondary_adjusted, accent_adjusted, background, theme_type)
    end

    def self.find_best_pairs(palette : Array(RGB), level : WCAGLevel = WCAGLevel::AA, large_text : Bool = false) : Array(ColorPair)
      return [] of ColorPair if palette.size < 2

      pairs = [] of ColorPair
      
      palette.each do |bg|
        palette.each do |text|
          next if bg == text
          
          text_level = Accessibility.wcag_level(text, bg, large_text)
          if text_level >= level
            ratio = Accessibility.contrast_ratio(text, bg)
            pairs << ColorPair.new(bg, text, ratio, text_level)
          end
        end
      end

      pairs.sort_by(&.contrast_ratio).reverse
    end

    def self.filter_for_light_theme(palette : Array(RGB)) : Array(RGB)
      palette.select do |color|
        theme = detect_theme(color)
        theme == :light
      end
    end

    def self.filter_for_dark_theme(palette : Array(RGB)) : Array(RGB)
      palette.select do |color|
        theme = detect_theme(color)
        theme == :dark
      end
    end

    def self.invert_for_theme(color : RGB) : RGB
      lum = Accessibility.relative_luminance(color)
      
      if lum > LUMINANCE_THRESHOLD
        inverted_lum = 1.0 - lum
        target_lum = inverted_lum * 0.8
        Accessibility.darken(color, 0.7)
      else
        inverted_lum = 1.0 - lum
        target_lum = inverted_lum * 0.8
        Accessibility.lighten(color, 0.7)
      end
    end

    def self.generate_dual_themes(source_palette : Array(RGB), level : WCAGLevel = WCAGLevel::AA) : DualThemePalette?
      return nil if source_palette.empty?

      light_candidates = filter_for_light_theme(source_palette)
      dark_candidates = filter_for_dark_theme(source_palette)

      light_bg = light_candidates.first? || Accessibility.lighten(source_palette.first, 0.7)
      dark_bg = dark_candidates.first? || Accessibility.darken(source_palette.first, 0.7)

      light_palette = suggest_text_palette(light_bg, level)
      dark_palette = suggest_text_palette(dark_bg, level)

      DualThemePalette.new(light_palette, dark_palette)
    end
  end
end
