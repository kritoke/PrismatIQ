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
end
