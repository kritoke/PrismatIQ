require "concurrent"

module PrismatIQ
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
    getter compliant : Bool

    def initialize(@color : RGB, @contrast_ratio : Float64, @level : WCAGLevel, @compliant : Bool)
    end
  end

  module Accessibility
    CONTRAST_RATIO_AA = 4.5
    CONTRAST_RATIO_AA_LARGE = 3.0
    CONTRAST_RATIO_AAA = 7.0
    CONTRAST_RATIO_AAA_LARGE = 4.5

    @@luminance_cache = Hash(Tuple(Int32, Int32, Int32), Float64).new
    @@contrast_cache = Hash(Tuple(Int32, Int32, Int32, Int32, Int32, Int32), Float64).new
    @@luminance_mutex = Mutex.new
    @@contrast_mutex = Mutex.new

    def self.clear_cache : Nil
      @@luminance_mutex.synchronize do
        @@luminance_cache.clear
      end
      @@contrast_mutex.synchronize do
        @@contrast_cache.clear
      end
    end

    def self.relative_luminance(rgb : RGB) : Float64
      key = {rgb.r, rgb.g, rgb.b}
      
      if cached = @@luminance_cache[key]?
        return cached
      end
      
      @@luminance_mutex.synchronize do
        @@luminance_cache[key] ||= begin
          r = rgb.r / 255.0
          g = rgb.g / 255.0
          b = rgb.b / 255.0

          r = r <= 0.03928 ? r / 12.92 : ((r + 0.055) / 1.055) ** 2.4
          g = g <= 0.03928 ? g / 12.92 : ((g + 0.055) / 1.055) ** 2.4
          b = b <= 0.03928 ? b / 12.92 : ((b + 0.055) / 1.055) ** 2.4

          0.2126 * r + 0.7152 * g + 0.0722 * b
        end
      end
      @@luminance_cache[key].not_nil!
    end

    def self.contrast_ratio(foreground : RGB, background : RGB) : Float64
      key = {foreground.r, foreground.g, foreground.b, background.r, background.g, background.b}
      
      if cached = @@contrast_cache[key]?
        return cached
      end
      
      @@contrast_mutex.synchronize do
        @@contrast_cache[key] ||= begin
          l1 = relative_luminance(foreground)
          l2 = relative_luminance(background)
          lighter = {l1, l2}.max
          darker = {l1, l2}.min
          (lighter + 0.05) / (darker + 0.05)
        end
      end
      @@contrast_cache[key].not_nil!
    end

    def self.wcag_level(foreground : RGB, background : RGB, large_text : Bool = false) : WCAGLevel
      ratio = contrast_ratio(foreground, background)

      if large_text
        return WCAGLevel::AAA if ratio >= CONTRAST_RATIO_AAA_LARGE
        return WCAGLevel::AA_Large if ratio >= CONTRAST_RATIO_AA_LARGE
        return WCAGLevel::Fail
      else
        return WCAGLevel::AAA if ratio >= CONTRAST_RATIO_AAA
        return WCAGLevel::AA if ratio >= CONTRAST_RATIO_AA
        return WCAGLevel::Fail
      end
    end

    def self.wcag_aa_compliant?(foreground : RGB, background : RGB) : Bool
      contrast_ratio(foreground, background) >= CONTRAST_RATIO_AA
    end

    def self.wcag_aaa_compliant?(foreground : RGB, background : RGB) : Bool
      contrast_ratio(foreground, background) >= CONTRAST_RATIO_AAA
    end

    def self.wcag_aa_large_compliant?(foreground : RGB, background : RGB) : Bool
      contrast_ratio(foreground, background) >= CONTRAST_RATIO_AA_LARGE
    end

    def self.wcag_aaa_large_compliant?(foreground : RGB, background : RGB) : Bool
      contrast_ratio(foreground, background) >= CONTRAST_RATIO_AAA_LARGE
    end

    def self.compliance_report(foreground : RGB, background : RGB) : ComplianceReport
      ratio = contrast_ratio(foreground, background)
      normal_level = wcag_level(foreground, background, large_text: false)
      large_level = wcag_level(foreground, background, large_text: true)

      recommendations = [] of String

      if normal_level < WCAGLevel::AA
        if ratio < CONTRAST_RATIO_AA
          recommendations << "Consider adjusting colors for normal text WCAG AA compliance (need #{CONTRAST_RATIO_AA}:1, have #{ratio.round(2)}:1)"
        end
      end

      if large_level < WCAGLevel::AA
        if ratio < CONTRAST_RATIO_AA_LARGE
          recommendations << "Consider adjusting colors for large text WCAG AA compliance (need #{CONTRAST_RATIO_AA_LARGE}:1, have #{ratio.round(2)}:1)"
        end
      end

      if normal_level == WCAGLevel::AAA
        recommendations << "Excellent! This combination meets WCAG AAA standards for normal text"
      end

      ComplianceReport.new(foreground, background, ratio, normal_level, large_level, recommendations)
    end

    def self.check_palette_compliance(palette : Array(RGB), background : RGB, large_text : Bool = false, target_level : WCAGLevel = WCAGLevel::AA) : Array(PaletteComplianceEntry)
      palette.map do |color|
        ratio = contrast_ratio(color, background)
        level = wcag_level(color, background, large_text)
        compliant = level >= target_level
        PaletteComplianceEntry.new(color, ratio, level, compliant)
      end
    end

    def self.filter_compliant(palette : Array(RGB), background : RGB, level : WCAGLevel = WCAGLevel::AA, large_text : Bool = false) : Array(RGB)
      check_palette_compliance(palette, background, large_text, level)
        .select(&.compliant)
        .map(&.color)
    end

    def self.adjust_for_compliance(foreground : RGB, background : RGB, target_level : WCAGLevel = WCAGLevel::AA, large_text : Bool = false) : RGB?
      current_level = wcag_level(foreground, background, large_text)
      return foreground if current_level >= target_level

      target_ratio = case target_level
                     when WCAGLevel::AAA
                       large_text ? CONTRAST_RATIO_AAA_LARGE : CONTRAST_RATIO_AAA
                     when WCAGLevel::AA
                       large_text ? CONTRAST_RATIO_AA_LARGE : CONTRAST_RATIO_AA
                     else
                       return foreground
                     end

      bg_lum = relative_luminance(background)
      fg_lum = relative_luminance(foreground)

      if bg_lum > fg_lum
        step = 0.01
        adjusted = foreground
        100.times do
          adjusted = darken(adjusted, step)
          return adjusted if wcag_level(adjusted, background, large_text) >= target_level
        end
        nil
      else
        step = 0.01
        adjusted = foreground
        100.times do
          adjusted = lighten(adjusted, step)
          return adjusted if wcag_level(adjusted, background, large_text) >= target_level
        end
        nil
      end
    end

    def self.find_nearest_compliant(target : RGB, background : RGB, level : WCAGLevel = WCAGLevel::AA, large_text : Bool = false) : RGB?
      adjusted = adjust_for_compliance(target, background, level, large_text)
      return adjusted if adjusted

      candidates = [
        RGB.new(0, 0, 0),
        RGB.new(255, 255, 255),
        RGB.new(30, 30, 30),
        RGB.new(225, 225, 225),
      ]

      candidates.select do |c|
        wcag_level(c, background, large_text) >= level
      end.min_by do |c|
        target.distance_to(c)
      end
    end

    def self.lighten(color : RGB, amount : Float64) : RGB
      amount = amount.clamp(0.0, 1.0)
      r = (color.r + (255 - color.r) * amount).to_i.clamp(0, 255)
      g = (color.g + (255 - color.g) * amount).to_i.clamp(0, 255)
      b = (color.b + (255 - color.b) * amount).to_i.clamp(0, 255)
      RGB.new(r, g, b)
    end

    def self.darken(color : RGB, amount : Float64) : RGB
      amount = amount.clamp(0.0, 1.0)
      r = (color.r * (1.0 - amount)).to_i.clamp(0, 255)
      g = (color.g * (1.0 - amount)).to_i.clamp(0, 255)
      b = (color.b * (1.0 - amount)).to_i.clamp(0, 255)
      RGB.new(r, g, b)
    end

    def self.recommend_text_color(background : RGB, level : WCAGLevel = WCAGLevel::AA, large_text : Bool = false) : RGB
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
