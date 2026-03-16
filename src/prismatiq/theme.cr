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
end
