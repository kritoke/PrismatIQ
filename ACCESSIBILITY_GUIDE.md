# WCAG Accessibility

PrismatIQ provides comprehensive WCAG 2.0/2.1 accessibility support for color contrast compliance checking and calculation.

## Getting Started

All accessibility functionality is provided through the `AccessibilityCalculator` class, which must be instantiated:

```crystal
calculator = PrismatIQ::AccessibilityCalculator.new
```

This instance-based design ensures thread safety and isolated caching.

## Basic Compliance Checking

### Contrast Ratio Calculation

Calculate the contrast ratio between foreground and background colors:

```crystal
fg = PrismatIQ::RGB.new(50, 50, 50)
bg = PrismatIQ::RGB.new(255, 255, 255)
ratio = calculator.contrast_ratio(fg, bg)
puts "Contrast ratio: #{ratio}:1"  # => "Contrast ratio: 13.0:1"
```

### WCAG Compliance Levels

Check if colors meet specific WCAG compliance levels:

```crystal
# Check AA compliance (4.5:1 for normal text, 3:1 for large text)
aa_compliant = calculator.wcag_aa_compliant?(fg, bg)        # true
aaa_compliant = calculator.wcag_aaa_compliant?(fg, bg)     # false

# Check compliance level with large text consideration
level = calculator.wcag_level(fg, bg, large_text: true)    # WCAGLevel::AA_Large
```

### WCAG Level Enum

The `WCAGLevel` enum represents compliance levels:
- `Fail` - Below 3:1 contrast
- `AA_Large` - 3:1 or higher (AA for large text ≥18pt or ≥14pt bold)
- `AA` - 4.5:1 or higher (AA for normal text)
- `AAA` - 7:1 or higher (AAA for normal text)

## Advanced Accessibility Features

### Comprehensive Compliance Report

Get detailed accessibility information for a color pair:

```crystal
report = calculator.compliance_report(fg, bg)
puts report.foreground.to_hex           # "#323232"
puts report.background.to_hex           # "#ffffff"  
puts report.contrast_ratio             # 13.0
puts report.normal_text_level          # WCAGLevel::AAA
puts report.large_text_level           # WCAGLevel::AAA
puts report.recommendations            # ["Meets AAA compliance for normal text"]
```

### Palette Compliance Checking

Check multiple colors against a background for compliance:

```crystal
palette = [
  PrismatIQ::RGB.new(0, 0, 0),       # Compliant
  PrismatIQ::RGB.new(200, 200, 200), # Non-compliant
  PrismatIQ::RGB.new(50, 50, 50),    # Compliant
]
bg = PrismatIQ::RGB.new(255, 255, 255)

entries = calculator.check_palette_compliance(palette, bg, target_level: WCAGLevel::AA)
entries.each do |entry|
  puts "#{entry.color.to_hex}: #{entry.level} (#{entry.compliant? ? "✓" : "✗"})"
end
```

### Filter Compliant Colors

Extract only compliant colors from a palette:

```crystal
compliant_colors = calculator.filter_compliant(palette, bg, WCAGLevel::AA)
```

### Automatic Color Adjustment

Adjust non-compliant colors to meet WCAG requirements:

```crystal
light_gray = PrismatIQ::RGB.new(200, 200, 200)
white = PrismatIQ::RGB.new(255, 255, 255)

# Adjust to meet AA compliance
adjusted = calculator.adjust_for_compliance(light_gray, white, WCAGLevel::AA)
if adjusted
  new_level = calculator.wcag_level(adjusted, white)
  puts "Adjusted color: #{adjusted.to_hex} (#{new_level})"
end
```

### Find Nearest Compliant Color

Find the closest compliant color to a target:

```crystal
target = PrismatIQ::RGB.new(150, 150, 150)
nearest_compliant = calculator.find_nearest_compliant(target, white, WCAGLevel::AA)
```

## Color Manipulation Utilities

### Lighten/Darken Colors

Adjust colors by specified amounts:

```crystal
color = PrismatIQ::RGB.new(100, 100, 100)
lightened = calculator.lighten(color, 0.5)  # Lighten by 50%
darkened = calculator.darken(color, 0.3)    # Darken by 30%
```

### Recommend Text Colors

Automatically recommend appropriate text colors:

```crystal
background = PrismatIQ::RGB.new(240, 240, 240)
text_color = calculator.recommend_text_color(background, WCAGLevel::AA)
puts text_color.to_hex  # "#000000" (black for light background)
```

## Caching and Performance

The `AccessibilityCalculator` uses intelligent caching to improve performance:

- **Luminance values** are cached per RGB color
- **Contrast ratios** are cached per color pair
- **Compliance checks** benefit from cached luminance values

### Cache Management

```crystal
# Clear all cached values
calculator.clear_cache

# Cache is automatically used on subsequent calls
lum1 = calculator.relative_luminance(color)
lum2 = calculator.relative_luminance(color)  # Returns cached value
```

### Thread Safety

Each `AccessibilityCalculator` instance is completely thread-safe:

```crystal
calculator = PrismatIQ::AccessibilityCalculator.new

# Safe to use concurrently from multiple fibers
100.times do |i|
  spawn do
    color = PrismatIQ::RGB.new(i % 256, (i * 2) % 256, (i * 3) % 256)
    lum = calculator.relative_luminance(color)
    # Process luminance...
  end
end
```

## Integration Examples

### Theme-Aware Accessibility

Combine with theme detection for complete solutions:

```crystal
detector = PrismatIQ::ThemeDetector.new
calculator = PrismatIQ::AccessibilityCalculator.new

background = PrismatIQ::RGB.new(240, 240, 240)
theme = detector.detect_theme(background)

# Get compliant text palette for the detected theme
text_palette = detector.suggest_text_palette(background, WCAGLevel::AA)

# Verify compliance
primary_ok = calculator.wcag_aa_compliant?(text_palette.primary, background)
```

### Batch Processing

Process multiple images with accessibility checks:

```crystal
def process_image_with_accessibility(path, options)
  result = PrismatIQ.get_palette_v2(path, options)
  return nil unless result.ok?
  
  palette = result.value
  calculator = PrismatIQ::AccessibilityCalculator.new
  
  # Find best accessible color pairs
  pairs = [] of PrismatIQ::ColorPair
  palette.each do |bg|
    palette.each do |fg|
      next if fg == bg
      if calculator.wcag_aa_compliant?(fg, bg)
        ratio = calculator.contrast_ratio(fg, bg)
        level = calculator.wcag_level(fg, bg)
        pairs << PrismatIQ::ColorPair.new(bg, fg, ratio, level)
      end
    end
  end
  
  pairs.sort_by!(&.contrast_ratio).reverse!
end
```

## Error Handling

Accessibility methods can raise validation errors for invalid parameters:

```crystal
begin
  # This will raise ValidationError for out-of-range values
  calculator.lighten(PrismatIQ::RGB.new(100, 100, 100), 1.5)
rescue ex : PrismatIQ::ValidationError
  puts "Invalid parameter: #{ex.message}"
end
```

For most use cases, the standard methods handle edge cases gracefully and return valid results.