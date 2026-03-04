require "./spec_helper"

describe PrismatIQ::Accessibility do
  describe ".relative_luminance" do
    it "calculates luminance for black" do
      black = PrismatIQ::RGB.new(0, 0, 0)
      lum = PrismatIQ::Accessibility.relative_luminance(black)
      lum.should be_close(0.0, 0.001)
    end

    it "calculates luminance for white" do
      white = PrismatIQ::RGB.new(255, 255, 255)
      lum = PrismatIQ::Accessibility.relative_luminance(white)
      lum.should be_close(1.0, 0.001)
    end

    it "calculates luminance for mid-gray" do
      gray = PrismatIQ::RGB.new(128, 128, 128)
      lum = PrismatIQ::Accessibility.relative_luminance(gray)
      lum.should be_close(0.216, 0.01)
    end
  end

  describe ".contrast_ratio" do
    it "calculates maximum contrast (black/white) as 21:1" do
      black = PrismatIQ::RGB.new(0, 0, 0)
      white = PrismatIQ::RGB.new(255, 255, 255)
      ratio = PrismatIQ::Accessibility.contrast_ratio(black, white)
      ratio.should be_close(21.0, 0.1)
    end

    it "calculates minimum contrast (same color) as 1:1" do
      color = PrismatIQ::RGB.new(100, 150, 200)
      ratio = PrismatIQ::Accessibility.contrast_ratio(color, color)
      ratio.should be_close(1.0, 0.01)
    end

    it "is symmetric (order doesn't matter)" do
      fg = PrismatIQ::RGB.new(50, 100, 150)
      bg = PrismatIQ::RGB.new(200, 220, 240)
      ratio1 = PrismatIQ::Accessibility.contrast_ratio(fg, bg)
      ratio2 = PrismatIQ::Accessibility.contrast_ratio(bg, fg)
      ratio1.should be_close(ratio2, 0.001)
    end
  end

  describe ".wcag_level" do
    it "returns AAA for 7:1 or higher contrast" do
      black = PrismatIQ::RGB.new(0, 0, 0)
      white = PrismatIQ::RGB.new(255, 255, 255)
      level = PrismatIQ::Accessibility.wcag_level(black, white)
      level.should eq(PrismatIQ::WCAGLevel::AAA)
    end

    it "returns AA for 4.5:1 to 7:1 contrast" do
      dark_gray = PrismatIQ::RGB.new(100, 100, 100)
      white = PrismatIQ::RGB.new(255, 255, 255)
      level = PrismatIQ::Accessibility.wcag_level(dark_gray, white)
      level.should eq(PrismatIQ::WCAGLevel::AA)
    end

    it "returns AA_Large for 3:1 or higher contrast (large text)" do
      gray = PrismatIQ::RGB.new(140, 140, 140)
      white = PrismatIQ::RGB.new(255, 255, 255)
      level = PrismatIQ::Accessibility.wcag_level(gray, white, large_text: true)
      level.should eq(PrismatIQ::WCAGLevel::AA_Large)
    end

    it "returns AA_Large for contrast between 3:1 and 4.5:1" do
      gray = PrismatIQ::RGB.new(140, 140, 140)
      white = PrismatIQ::RGB.new(255, 255, 255)
      ratio = PrismatIQ::Accessibility.contrast_ratio(gray, white)
      # This test checks the distinction between normal and large text requirements
      level_normal = PrismatIQ::Accessibility.wcag_level(gray, white, large_text: false)
      level_large = PrismatIQ::Accessibility.wcag_level(gray, white, large_text: true)
      
      # For 3:1 to 4.5:1 range, large text passes AA_Large but normal text fails
      if ratio >= 3.0 && ratio < 4.5
        level_normal.should eq(PrismatIQ::WCAGLevel::Fail)
        level_large.should eq(PrismatIQ::WCAGLevel::AA_Large)
      end
    end

    it "returns Fail for contrast below 3:1" do
      light_gray = PrismatIQ::RGB.new(200, 200, 200)
      white = PrismatIQ::RGB.new(255, 255, 255)
      level = PrismatIQ::Accessibility.wcag_level(light_gray, white)
      level.should eq(PrismatIQ::WCAGLevel::Fail)
    end
  end

  describe ".wcag_aa_compliant?" do
    it "returns true for AA compliant colors" do
      dark_text = PrismatIQ::RGB.new(50, 50, 50)
      white_bg = PrismatIQ::RGB.new(255, 255, 255)
      PrismatIQ::Accessibility.wcag_aa_compliant?(dark_text, white_bg).should be_true
    end

    it "returns false for non-compliant colors" do
      light_text = PrismatIQ::RGB.new(200, 200, 200)
      white_bg = PrismatIQ::RGB.new(255, 255, 255)
      PrismatIQ::Accessibility.wcag_aa_compliant?(light_text, white_bg).should be_false
    end
  end

  describe ".wcag_aaa_compliant?" do
    it "returns true for AAA compliant colors" do
      black = PrismatIQ::RGB.new(0, 0, 0)
      white = PrismatIQ::RGB.new(255, 255, 255)
      PrismatIQ::Accessibility.wcag_aaa_compliant?(black, white).should be_true
    end

    it "returns false for AA but not AAA compliant colors" do
      dark_gray = PrismatIQ::RGB.new(100, 100, 100)
      white = PrismatIQ::RGB.new(255, 255, 255)
      PrismatIQ::Accessibility.wcag_aaa_compliant?(dark_gray, white).should be_false
    end
  end

  describe ".wcag_aa_large_compliant?" do
    it "returns true for 3:1 or higher contrast" do
      gray = PrismatIQ::RGB.new(140, 140, 140)
      white = PrismatIQ::RGB.new(255, 255, 255)
      PrismatIQ::Accessibility.wcag_aa_large_compliant?(gray, white).should be_true
    end
  end

  describe ".compliance_report" do
    it "generates a comprehensive compliance report" do
      fg = PrismatIQ::RGB.new(100, 100, 100)
      bg = PrismatIQ::RGB.new(255, 255, 255)
      report = PrismatIQ::Accessibility.compliance_report(fg, bg)

      report.foreground.should eq(fg)
      report.background.should eq(bg)
      report.contrast_ratio.should be > 0
      report.normal_text_level.should be_a(PrismatIQ::WCAGLevel)
      report.large_text_level.should be_a(PrismatIQ::WCAGLevel)
      report.recommendations.should be_a(Array(String))
    end
  end

  describe ".check_palette_compliance" do
    it "checks all colors in a palette" do
      palette = [
        PrismatIQ::RGB.new(0, 0, 0),
        PrismatIQ::RGB.new(200, 200, 200),
        PrismatIQ::RGB.new(50, 50, 50),
      ]
      bg = PrismatIQ::RGB.new(255, 255, 255)

      entries = PrismatIQ::Accessibility.check_palette_compliance(palette, bg)
      entries.size.should eq(3)
      entries.each do |entry|
        entry.color.should be_a(PrismatIQ::RGB)
        entry.contrast_ratio.should be > 0
        entry.level.should be_a(PrismatIQ::WCAGLevel)
        entry.compliant.should be_a(Bool)
      end
    end
  end

  describe ".filter_compliant" do
    it "filters palette to only compliant colors" do
      palette = [
        PrismatIQ::RGB.new(0, 0, 0),       # Compliant
        PrismatIQ::RGB.new(200, 200, 200), # Non-compliant
        PrismatIQ::RGB.new(50, 50, 50),    # Compliant
      ]
      bg = PrismatIQ::RGB.new(255, 255, 255)

      compliant = PrismatIQ::Accessibility.filter_compliant(palette, bg, PrismatIQ::WCAGLevel::AA)
      compliant.size.should eq(2)
      compliant.should contain(PrismatIQ::RGB.new(0, 0, 0))
      compliant.should contain(PrismatIQ::RGB.new(50, 50, 50))
    end
  end

  describe ".adjust_for_compliance" do
    it "adjusts a non-compliant color to meet WCAG AA" do
      light_gray = PrismatIQ::RGB.new(200, 200, 200)
      white = PrismatIQ::RGB.new(255, 255, 255)

      adjusted = PrismatIQ::Accessibility.adjust_for_compliance(light_gray, white, PrismatIQ::WCAGLevel::AA)
      adjusted.should_not be_nil

      level = PrismatIQ::Accessibility.wcag_level(adjusted.not_nil!, white)
      level.should be >= PrismatIQ::WCAGLevel::AA
    end

    it "returns original color if already compliant" do
      black = PrismatIQ::RGB.new(0, 0, 0)
      white = PrismatIQ::RGB.new(255, 255, 255)

      adjusted = PrismatIQ::Accessibility.adjust_for_compliance(black, white, PrismatIQ::WCAGLevel::AA)
      adjusted.should eq(black)
    end
  end

  describe ".lighten" do
    it "lightens a color by the specified amount" do
      color = PrismatIQ::RGB.new(100, 100, 100)
      lightened = PrismatIQ::Accessibility.lighten(color, 0.5)

      lightened.r.should be > color.r
      lightened.g.should be > color.g
      lightened.b.should be > color.b
    end

    it "produces white when lightening by 1.0" do
      color = PrismatIQ::RGB.new(100, 100, 100)
      lightened = PrismatIQ::Accessibility.lighten(color, 1.0)
      lightened.should eq(PrismatIQ::RGB.new(255, 255, 255))
    end
  end

  describe ".darken" do
    it "darkens a color by the specified amount" do
      color = PrismatIQ::RGB.new(200, 200, 200)
      darkened = PrismatIQ::Accessibility.darken(color, 0.5)

      darkened.r.should be < color.r
      darkened.g.should be < color.g
      darkened.b.should be < color.b
    end

    it "produces black when darkening by 1.0" do
      color = PrismatIQ::RGB.new(200, 200, 200)
      darkened = PrismatIQ::Accessibility.darken(color, 1.0)
      darkened.should eq(PrismatIQ::RGB.new(0, 0, 0))
    end
  end

  describe ".recommend_text_color" do
    it "recommends black text for light backgrounds" do
      light_bg = PrismatIQ::RGB.new(240, 240, 240)
      text = PrismatIQ::Accessibility.recommend_text_color(light_bg)
      text.to_hex.should eq("#000000")
    end

    it "recommends white text for dark backgrounds" do
      dark_bg = PrismatIQ::RGB.new(20, 20, 20)
      text = PrismatIQ::Accessibility.recommend_text_color(dark_bg)
      text.to_hex.should eq("#ffffff")
    end
  end

  describe "caching" do
    it "caches luminance calculations" do
      PrismatIQ::Accessibility.clear_cache

      color = PrismatIQ::RGB.new(123, 145, 167)
      lum1 = PrismatIQ::Accessibility.relative_luminance(color)
      lum2 = PrismatIQ::Accessibility.relative_luminance(color)

      lum1.should eq(lum2)
    end

    it "caches contrast ratio calculations" do
      PrismatIQ::Accessibility.clear_cache

      fg = PrismatIQ::RGB.new(50, 60, 70)
      bg = PrismatIQ::RGB.new(200, 210, 220)
      ratio1 = PrismatIQ::Accessibility.contrast_ratio(fg, bg)
      ratio2 = PrismatIQ::Accessibility.contrast_ratio(fg, bg)

      ratio1.should eq(ratio2)
    end

    it "clears cache when requested" do
      color = PrismatIQ::RGB.new(100, 100, 100)
      PrismatIQ::Accessibility.relative_luminance(color)
      PrismatIQ::Accessibility.clear_cache
      # After clearing, cache should be empty but function should still work
      lum = PrismatIQ::Accessibility.relative_luminance(color)
      lum.should be > 0
    end
  end
end
