require "./thread_safe_cache"

module PrismatIQ
  # Import ThreadSafeCache - moved to top level

  enum WCAGLevel
    Fail     = 0
    AA_Large = 1
    AA       = 2
    AAA      = 3
  end

  struct ComplianceReport
    getter foreground : RGB
    getter background : RGB
    getter contrast_ratio : Float64
    getter normal_text_level : WCAGLevel
    getter large_text_level : WCAGLevel
    getter recommendations : Array(String)

    def initialize(@foreground : RGB, @background : RGB, @contrast_ratio : Float64,
                   @normal_text_level : WCAGLevel, @large_text_level : WCAGLevel,
                   @recommendations : Array(String))
    end
  end

  struct PaletteComplianceEntry
    getter color : RGB
    getter contrast_ratio : Float64
    getter level : WCAGLevel
    getter? compliant : Bool

    def initialize(@color : RGB, @contrast_ratio : Float64, @level : WCAGLevel, @compliant : Bool)
    end
  end

  module Accessibility
    # Thread-safe cache for luminance values using ThreadSafeCache
    private def self.calculator
      @@calculator ||= AccessibilityCalculator.new
    end

    def self.clear_cache : Nil
      calculator.clear_cache
    end

    def self.relative_luminance(rgb : RGB) : Float64
      calculator.relative_luminance(rgb)
    end

    def self.contrast_ratio(foreground : RGB, background : RGB) : Float64
      calculator.contrast_ratio(foreground, background)
    end

    def self.wcag_level(foreground : RGB, background : RGB, large_text : Bool = false) : WCAGLevel
      calculator.wcag_level(foreground, background, large_text)
    end

    def self.wcag_aa_compliant?(foreground : RGB, background : RGB) : Bool
      calculator.wcag_aa_compliant?(foreground, background)
    end

    def self.wcag_aaa_compliant?(foreground : RGB, background : RGB) : Bool
      calculator.wcag_aaa_compliant?(foreground, background)
    end

    def self.wcag_aa_large_compliant?(foreground : RGB, background : RGB) : Bool
      calculator.wcag_aa_large_compliant?(foreground, background)
    end

    def self.wcag_aaa_large_compliant?(foreground : RGB, background : RGB) : Bool
      calculator.wcag_aaa_large_compliant?(foreground, background)
    end

    def self.compliance_report(foreground : RGB, background : RGB) : ComplianceReport
      calculator.compliance_report(foreground, background)
    end

    def self.check_palette_compliance(palette : Array(RGB), background : RGB, large_text : Bool = false, target_level : WCAGLevel = WCAGLevel::AA) : Array(PaletteComplianceEntry)
      calculator.check_palette_compliance(palette, background, large_text, target_level)
    end

    def self.filter_compliant(palette : Array(RGB), background : RGB, level : WCAGLevel = WCAGLevel::AA, large_text : Bool = false) : Array(RGB)
      calculator.filter_compliant(palette, background, level, large_text)
    end

    def self.adjust_for_compliance(foreground : RGB, background : RGB, target_level : WCAGLevel = WCAGLevel::AA, large_text : Bool = false) : RGB?
      calculator.adjust_for_compliance(foreground, background, target_level, large_text)
    end

    def self.find_nearest_compliant(target : RGB, background : RGB, level : WCAGLevel = WCAGLevel::AA, large_text : Bool = false) : RGB?
      calculator.find_nearest_compliant(target, background, level, large_text)
    end

    def self.lighten(color : RGB, amount : Float64) : RGB
      calculator.lighten(color, amount)
    end

    def self.darken(color : RGB, amount : Float64) : RGB
      calculator.darken(color, amount)
    end

    def self.recommend_text_color(background : RGB, level : WCAGLevel = WCAGLevel::AA, large_text : Bool = false) : RGB
      calculator.recommend_text_color(background, level, large_text)
    end
  end
end
