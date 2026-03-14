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
    # Backward compatibility: alias to Constants::LUMINANCE_THRESHOLD
    LUMINANCE_THRESHOLD = Constants::LUMINANCE_THRESHOLD

    private def self.detector
      @@detector ||= ThemeDetector.new
    end

    def self.clear_cache : Nil
      detector.clear_cache
    end

    def self.detect_theme(background : RGB) : Symbol
      detector.detect_theme(background)
    end

    def self.analyze_theme(background : RGB) : ThemeInfo
      detector.analyze_theme(background)
    end

    def self.suggest_text_palette(background : RGB, level : WCAGLevel = WCAGLevel::AA) : TextColorPalette
      detector.suggest_text_palette(background, level)
    end

    # Convenience methods implemented directly using the detector and Accessibility

    def self.find_best_pairs(palette : Array(RGB), level : WCAGLevel = WCAGLevel::AA, large_text : Bool = false) : Array(ColorPair)
      return [] of ColorPair if palette.size < 2

      pairs = [] of ColorPair

      palette.each do |background_color|
        palette.each do |text_color|
          next if background_color == text_color

          text_level = Accessibility.wcag_level(text_color, background_color, large_text)
          if text_level >= level
            ratio = Accessibility.contrast_ratio(text_color, background_color)
            pairs << ColorPair.new(background_color, text_color, ratio, text_level)
          end
        end
      end

      pairs.sort_by!(&.contrast_ratio).reverse!
    end

    def self.filter_for_light_theme(palette : Array(RGB)) : Array(RGB)
      palette.select { |color| detect_theme(color) == :light }
    end

    def self.filter_for_dark_theme(palette : Array(RGB)) : Array(RGB)
      palette.select { |color| detect_theme(color) == :dark }
    end

    def self.invert_for_theme(color : RGB) : RGB
      lum = Accessibility.relative_luminance(color)
      if lum > LUMINANCE_THRESHOLD
        Accessibility.darken(color, 0.7)
      else
        Accessibility.lighten(color, 0.7)
      end
    end

    def self.generate_dual_themes(source_palette : Array(RGB), level : WCAGLevel = WCAGLevel::AA) : DualThemePalette?
      return if source_palette.empty?

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
