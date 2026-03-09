require "./thread_safe_cache"
require "./rgb"

module PrismatIQ
  class AccessibilityCalculator
    @luminance_cache : ThreadSafeCache(Tuple(Int32, Int32, Int32), Float64)
    @contrast_cache : ThreadSafeCache(Tuple(Int32, Int32, Int32, Int32, Int32, Int32), Float64)

    def initialize
      @luminance_cache = ThreadSafeCache(Tuple(Int32, Int32, Int32), Float64).new
      @contrast_cache = ThreadSafeCache(Tuple(Int32, Int32, Int32, Int32, Int32, Int32), Float64).new
    end

    def clear_cache : Nil
      @luminance_cache.clear
      @contrast_cache.clear
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

    def contrast_ratio(foreground : RGB, background : RGB) : Float64
      key = {foreground.r, foreground.g, foreground.b, background.r, background.g, background.b}

      @contrast_cache.get_or_compute(key) do
        l1 = relative_luminance(foreground)
        l2 = relative_luminance(background)
        lighter = {l1, l2}.max
        darker = {l1, l2}.min
        (lighter + 0.05) / (darker + 0.05)
      end
    end

    def wcag_level(foreground : RGB, background : RGB, large_text : Bool = false) : WCAGLevel
      ratio = contrast_ratio(foreground, background)

      if large_text
        return WCAGLevel::AAA if ratio >= Constants::WCAG::CONTRAST_RATIO_AAA_LARGE
        return WCAGLevel::AA_Large if ratio >= Constants::WCAG::CONTRAST_RATIO_AA_LARGE
        WCAGLevel::Fail
      else
        return WCAGLevel::AAA if ratio >= Constants::WCAG::CONTRAST_RATIO_AAA
        return WCAGLevel::AA if ratio >= Constants::WCAG::CONTRAST_RATIO_AA
        WCAGLevel::Fail
      end
    end

    def wcag_aa_compliant?(foreground : RGB, background : RGB) : Bool
      contrast_ratio(foreground, background) >= Constants::WCAG::CONTRAST_RATIO_AA
    end

    def wcag_aaa_compliant?(foreground : RGB, background : RGB) : Bool
      contrast_ratio(foreground, background) >= Constants::WCAG::CONTRAST_RATIO_AAA
    end

    def wcag_aa_large_compliant?(foreground : RGB, background : RGB) : Bool
      contrast_ratio(foreground, background) >= Constants::WCAG::CONTRAST_RATIO_AA_LARGE
    end

    def wcag_aaa_large_compliant?(foreground : RGB, background : RGB) : Bool
      contrast_ratio(foreground, background) >= Constants::WCAG::CONTRAST_RATIO_AAA_LARGE
    end

    def compliance_report(foreground : RGB, background : RGB) : ComplianceReport
      ratio = contrast_ratio(foreground, background)
      normal_level = wcag_level(foreground, background, large_text: false)
      large_level = wcag_level(foreground, background, large_text: true)

      recommendations = [] of String

      if normal_level < WCAGLevel::AA
        if ratio < Constants::WCAG::CONTRAST_RATIO_AA
          recommendations << "Consider adjusting colors for normal text WCAG AA compliance (need #{Constants::WCAG::CONTRAST_RATIO_AA}:1, have #{ratio.round(2)}:1)"
        end
      end

      if large_level < WCAGLevel::AA
        if ratio < Constants::WCAG::CONTRAST_RATIO_AA_LARGE
          recommendations << "Consider adjusting colors for large text WCAG AA compliance (need #{Constants::WCAG::CONTRAST_RATIO_AA_LARGE}:1, have #{ratio.round(2)}:1)"
        end
      end

      if normal_level == WCAGLevel::AAA
        recommendations << "Excellent! This combination meets WCAG AAA standards for normal text"
      end

      ComplianceReport.new(foreground, background, ratio, normal_level, large_level, recommendations)
    end

    def check_palette_compliance(palette : Array(RGB), background : RGB, large_text : Bool = false, target_level : WCAGLevel = WCAGLevel::AA) : Array(PaletteComplianceEntry)
      palette.map do |color|
        ratio = contrast_ratio(color, background)
        level = wcag_level(color, background, large_text)
        compliant = level >= target_level
        PaletteComplianceEntry.new(color, ratio, level, compliant)
      end
    end

    def suggest_accessible_alternatives(color : RGB, background : RGB, large_text : Bool = false) : Array(RGB)
      suggestions = [] of RGB
      current_ratio = contrast_ratio(color, background)
      target_ratio = large_text ? Constants::WCAG::CONTRAST_RATIO_AA_LARGE : Constants::WCAG::CONTRAST_RATIO_AA

      return suggestions if current_ratio >= target_ratio

      (0..255).step(10) do |adjustment|
        adjusted = RGB.new(
          (color.r + adjustment).clamp(0, 255),
          (color.g + adjustment).clamp(0, 255),
          (color.b + adjustment).clamp(0, 255)
        )

        if contrast_ratio(adjusted, background) >= target_ratio
          suggestions << adjusted
          break if suggestions.size >= 5
        end
      end

      suggestions
    end
  end
end
