require "./thread_safe_cache"
require "./rgb"
require "./luminance_calculator"

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
        LuminanceCalculator.relative_luminance(rgb)
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

    def filter_compliant(palette : Array(RGB), background : RGB, level : WCAGLevel = WCAGLevel::AA, large_text : Bool = false) : Array(RGB)
      check_palette_compliance(palette, background, large_text, level)
        .select(&.compliant?)
        .map(&.color)
    end

    def adjust_for_compliance(foreground : RGB, background : RGB, target_level : WCAGLevel = WCAGLevel::AA, large_text : Bool = false) : RGB?
      current_level = wcag_level(foreground, background, large_text)
      return foreground if current_level >= target_level

      bg_lum = relative_luminance(background)
      fg_lum = relative_luminance(foreground)

      if bg_lum > fg_lum
        # Background is lighter, try darkening foreground
        (1..100).each do |i|
          amount = i * 0.01
          adjusted = darken(foreground, amount)
          if wcag_level(adjusted, background, large_text) >= target_level
            return adjusted
          end
        end
      else
        # Background is darker, try lightening foreground
        (1..100).each do |i|
          amount = i * 0.01
          adjusted = lighten(foreground, amount)
          if wcag_level(adjusted, background, large_text) >= target_level
            return adjusted
          end
        end
      end

      nil
    end

    def find_nearest_compliant(target : RGB, background : RGB, level : WCAGLevel = WCAGLevel::AA, large_text : Bool = false) : RGB?
      adjusted = adjust_for_compliance(target, background, level, large_text)
      return adjusted if adjusted

      candidates = [
        RGB.new(0, 0, 0),
        RGB.new(255, 255, 255),
        RGB.new(30, 30, 30),
        RGB.new(225, 225, 225),
      ]

      compliant_candidates = candidates.select do |candidate|
        wcag_level(candidate, background, large_text) >= level
      end

      return if compliant_candidates.empty?

      compliant_candidates.min_by do |candidate|
        target.distance_to(candidate)
      end
    end

    def lighten(color : RGB, amount : Float64) : RGB
      amount = amount.clamp(0.0, 1.0)
      r = (color.r + (255 - color.r) * amount).to_i.clamp(0, 255)
      g = (color.g + (255 - color.g) * amount).to_i.clamp(0, 255)
      b = (color.b + (255 - color.b) * amount).to_i.clamp(0, 255)
      RGB.new(r, g, b)
    end

    def darken(color : RGB, amount : Float64) : RGB
      amount = amount.clamp(0.0, 1.0)
      r = (color.r * (1.0 - amount)).to_i.clamp(0, 255)
      g = (color.g * (1.0 - amount)).to_i.clamp(0, 255)
      b = (color.b * (1.0 - amount)).to_i.clamp(0, 255)
      RGB.new(r, g, b)
    end

    def recommend_text_color(background : RGB, level : WCAGLevel = WCAGLevel::AA, large_text : Bool = false) : RGB
      black = RGB.new(0, 0, 0)
      white = RGB.new(255, 255, 255)

      black_level = wcag_level(black, background, large_text)
      white_level = wcag_level(white, background, large_text)

      if black_level >= level && white_level >= level
        bg_lum = relative_luminance(background)
        bg_lum > 0.5 ? black : white
      elsif black_level >= level
        black
      elsif white_level >= level
        white
      else
        bg_lum = relative_luminance(background)
        bg_lum > 0.5 ? black : white
      end
    end
  end
end
