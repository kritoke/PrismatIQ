require "./spec_helper"

describe PrismatIQ::Theme do
  describe ".detect_theme" do
    it "identifies white as light theme" do
      white = PrismatIQ::RGB.new(255, 255, 255)
      PrismatIQ::Theme.detect_theme(white).should eq(:light)
    end

    it "identifies black as dark theme" do
      black = PrismatIQ::RGB.new(0, 0, 0)
      PrismatIQ::Theme.detect_theme(black).should eq(:dark)
    end

    it "identifies light colors as light theme" do
      light_color = PrismatIQ::RGB.new(240, 240, 240)
      PrismatIQ::Theme.detect_theme(light_color).should eq(:light)
    end

    it "identifies dark colors as dark theme" do
      dark_color = PrismatIQ::RGB.new(30, 30, 30)
      PrismatIQ::Theme.detect_theme(dark_color).should eq(:dark)
    end
  end

  describe ".analyze_theme" do
    it "provides detailed theme information" do
      color = PrismatIQ::RGB.new(128, 128, 128)
      info = PrismatIQ::Theme.analyze_theme(color)

      info.type.should be_a(Symbol)
      info.luminance.should be >= 0.0
      info.luminance.should be <= 1.0
      info.perceived_brightness.should be >= 0.0
      info.perceived_brightness.should be <= 1.0
    end
  end

  describe ".suggest_text_palette" do
    it "generates a text palette for light theme" do
      light_bg = PrismatIQ::RGB.new(245, 245, 245)
      palette = PrismatIQ::Theme.suggest_text_palette(light_bg)

      palette.theme_type.should eq(:light)
      palette.background.should eq(light_bg)
      palette.primary.should be_a(PrismatIQ::RGB)
      palette.secondary.should be_a(PrismatIQ::RGB)
      palette.accent.should be_a(PrismatIQ::RGB)
    end

    it "generates a text palette for dark theme" do
      dark_bg = PrismatIQ::RGB.new(30, 30, 30)
      palette = PrismatIQ::Theme.suggest_text_palette(dark_bg)

      palette.theme_type.should eq(:dark)
      palette.background.should eq(dark_bg)
      palette.primary.should be_a(PrismatIQ::RGB)
      palette.secondary.should be_a(PrismatIQ::RGB)
      palette.accent.should be_a(PrismatIQ::RGB)
    end

    it "ensures primary text is compliant" do
      bg = PrismatIQ::RGB.new(100, 100, 100)
      palette = PrismatIQ::Theme.suggest_text_palette(bg, PrismatIQ::WCAGLevel::AA)

      level = PrismatIQ::Accessibility.wcag_level(palette.primary, bg)
      level.should be >= PrismatIQ::WCAGLevel::AA
    end
  end

  describe ".find_best_pairs" do
    it "finds compliant color pairs from a palette" do
      palette = [
        PrismatIQ::RGB.new(0, 0, 0),
        PrismatIQ::RGB.new(255, 255, 255),
        PrismatIQ::RGB.new(100, 100, 100),
        PrismatIQ::RGB.new(200, 200, 200),
      ]

      pairs = PrismatIQ::Theme.find_best_pairs(palette, PrismatIQ::WCAGLevel::AA)
      pairs.size.should be > 0

      pairs.each do |pair|
        pair.background.should be_a(PrismatIQ::RGB)
        pair.text.should be_a(PrismatIQ::RGB)
        pair.contrast_ratio.should be > 0
        pair.compliance_level.should be >= PrismatIQ::WCAGLevel::AA
      end
    end

    it "returns empty array for single-color palette" do
      palette = [PrismatIQ::RGB.new(128, 128, 128)]
      pairs = PrismatIQ::Theme.find_best_pairs(palette)
      pairs.size.should eq(0)
    end

    it "sorts pairs by contrast ratio (highest first)" do
      palette = [
        PrismatIQ::RGB.new(0, 0, 0),
        PrismatIQ::RGB.new(255, 255, 255),
        PrismatIQ::RGB.new(100, 100, 100),
      ]

      pairs = PrismatIQ::Theme.find_best_pairs(palette)
      if pairs.size >= 2
        pairs[0].contrast_ratio.should be >= pairs[1].contrast_ratio
      end
    end
  end

  describe ".filter_for_light_theme" do
    it "filters palette to only light colors" do
      palette = [
        PrismatIQ::RGB.new(255, 255, 255), # Light
        PrismatIQ::RGB.new(0, 0, 0),       # Dark
        PrismatIQ::RGB.new(240, 240, 240), # Light
        PrismatIQ::RGB.new(30, 30, 30),    # Dark
      ]

      light_colors = PrismatIQ::Theme.filter_for_light_theme(palette)
      light_colors.size.should eq(2)
      light_colors.should contain(PrismatIQ::RGB.new(255, 255, 255))
      light_colors.should contain(PrismatIQ::RGB.new(240, 240, 240))
    end
  end

  describe ".filter_for_dark_theme" do
    it "filters palette to only dark colors" do
      palette = [
        PrismatIQ::RGB.new(255, 255, 255), # Light
        PrismatIQ::RGB.new(0, 0, 0),       # Dark
        PrismatIQ::RGB.new(240, 240, 240), # Light
        PrismatIQ::RGB.new(30, 30, 30),    # Dark
      ]

      dark_colors = PrismatIQ::Theme.filter_for_dark_theme(palette)
      dark_colors.size.should eq(2)
      dark_colors.should contain(PrismatIQ::RGB.new(0, 0, 0))
      dark_colors.should contain(PrismatIQ::RGB.new(30, 30, 30))
    end
  end

  describe ".invert_for_theme" do
    it "lightens dark colors" do
      dark = PrismatIQ::RGB.new(30, 30, 30)
      inverted = PrismatIQ::Theme.invert_for_theme(dark)

      inverted.r.should be > dark.r
      inverted.g.should be > dark.g
      inverted.b.should be > dark.b
    end

    it "darkens light colors" do
      light = PrismatIQ::RGB.new(220, 220, 220)
      inverted = PrismatIQ::Theme.invert_for_theme(light)

      inverted.r.should be < light.r
      inverted.g.should be < light.g
      inverted.b.should be < light.b
    end
  end

  describe ".generate_dual_themes" do
    it "generates both light and dark theme palettes" do
      source = [
        PrismatIQ::RGB.new(0, 0, 0),
        PrismatIQ::RGB.new(255, 255, 255),
        PrismatIQ::RGB.new(100, 100, 100),
      ]

      dual = PrismatIQ::Theme.generate_dual_themes(source)
      dual.should_not be_nil

      dual.not_nil!.light.should be_a(PrismatIQ::TextColorPalette)
      dual.not_nil!.dark.should be_a(PrismatIQ::TextColorPalette)
      dual.not_nil!.light.theme_type.should eq(:light)
      dual.not_nil!.dark.theme_type.should eq(:dark)
    end

    it "returns nil for empty palette" do
      dual = PrismatIQ::Theme.generate_dual_themes([] of PrismatIQ::RGB)
      dual.should be_nil
    end

    it "ensures both themes are compliant" do
      source = [
        PrismatIQ::RGB.new(50, 50, 50),
        PrismatIQ::RGB.new(200, 200, 200),
      ]

      dual = PrismatIQ::Theme.generate_dual_themes(source, PrismatIQ::WCAGLevel::AA)
      dual.should_not be_nil

      light_primary_level = PrismatIQ::Accessibility.wcag_level(
        dual.not_nil!.light.primary,
        dual.not_nil!.light.background
      )
      dark_primary_level = PrismatIQ::Accessibility.wcag_level(
        dual.not_nil!.dark.primary,
        dual.not_nil!.dark.background
      )

      light_primary_level.should be >= PrismatIQ::WCAGLevel::AA
      dark_primary_level.should be >= PrismatIQ::WCAGLevel::AA
    end
  end

  describe "caching" do
    it "caches theme detection results" do
      PrismatIQ::Theme.clear_cache

      color = PrismatIQ::RGB.new(128, 128, 128)
      theme1 = PrismatIQ::Theme.detect_theme(color)
      theme2 = PrismatIQ::Theme.detect_theme(color)

      theme1.should eq(theme2)
    end

    it "clears cache when requested" do
      color = PrismatIQ::RGB.new(100, 100, 100)
      PrismatIQ::Theme.detect_theme(color)
      PrismatIQ::Theme.clear_cache
      # After clearing, cache should be empty but function should still work
      theme = PrismatIQ::Theme.detect_theme(color)
      theme.should be_a(Symbol)
    end
  end

  describe "integration with Accessibility" do
    it "uses Accessibility module for compliance checking" do
      palette = [
        PrismatIQ::RGB.new(0, 0, 0),
        PrismatIQ::RGB.new(255, 255, 255),
      ]

      text_palette = PrismatIQ::Theme.suggest_text_palette(palette[1], PrismatIQ::WCAGLevel::AAA)
      level = PrismatIQ::Accessibility.wcag_level(text_palette.primary, palette[1])
      
      level.should be >= PrismatIQ::WCAGLevel::AAA
    end
  end
end
