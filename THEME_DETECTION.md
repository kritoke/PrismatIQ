# Theme Detection

PrismatIQ provides comprehensive theme detection capabilities for automatically determining dark/light themes and generating appropriate color schemes.

## Getting Started

All theme functionality is provided through the `ThemeDetector` class, which must be instantiated:

```crystal
detector = PrismatIQ::ThemeDetector.new
```

This instance-based design ensures thread safety and isolated caching.

## Basic Theme Detection

### Detect Theme Type

Determine if a background color represents a light or dark theme:

```crystal
background = PrismatIQ::RGB.new(240, 240, 240)
theme = detector.detect_theme(background)
puts theme  # => :light

dark_bg = PrismatIQ::RGB.new(30, 30, 30)
theme = detector.detect_theme(dark_bg)
puts theme  # => :dark
```

### Analyze Theme Details

Get comprehensive theme information including luminance and perceived brightness:

```crystal
info = detector.analyze_theme(background)
puts "Theme type: #{info.type}"                 # :light
puts "Luminance: #{info.luminance}"           # 0.758
puts "Perceived brightness: #{info.perceived_brightness}"  # 0.758
```

### Helper Methods

Convenience methods for common checks:

```crystal
detector.light?(background)  # true for light backgrounds  
detector.dark?(background)   # true for dark backgrounds
```

## Text Palette Generation

### Automatically Generate Compliant Text Palettes

Create complete text palettes with WCAG-compliant colors:

```crystal
background = PrismatIQ::RGB.new(240, 240, 240)
palette = detector.suggest_text_palette(background, WCAGLevel::AA)

puts "Background: #{palette.background.to_hex}"    # "#f0f0f0"
puts "Primary:    #{palette.primary.to_hex}"       # "#000000"  
puts "Secondary:  #{palette.secondary.to_hex}"     # "#333333"
puts "Accent:     #{palette.accent.to_hex}"        # "#666666"
puts "Theme:      #{palette.theme_type}"           # :light
```

The generated palette includes:
- **Primary**: Main text color (highest contrast)
- **Secondary**: Secondary text color 
- **Accent**: Accent/tertiary text color
- **Background**: Original background color
- **Theme type**: Detected theme (:light or :dark)

### Suggest Individual Colors

Get individual color suggestions:

```crystal
# Suggest appropriate foreground color
fg = detector.suggest_foreground(background)  # Black for light bg

# Suggest appropriate background color  
bg = detector.suggest_background(fg)          # White for dark fg
```

## Color Pair Discovery

### Find Best Compliant Color Pairs

Discover all WCAG-compliant color combinations from a palette:

```crystal
source_palette = [
  PrismatIQ::RGB.new(0, 0, 0),       # Black
  PrismatIQ::RGB.new(255, 255, 255), # White  
  PrismatIQ::RGB.new(100, 100, 100), # Dark gray
  PrismatIQ::RGB.new(200, 200, 200), # Light gray
]

pairs = detector.find_best_pairs(source_palette, WCAGLevel::AA)

pairs.each do |pair|
  puts "Background: #{pair.background.to_hex} → Text: #{pair.text.to_hex}"
  puts "  Ratio: #{pair.contrast_ratio}:1 (#{pair.compliance_level})"
end
```

Each `ColorPair` contains:
- **background**: Background color
- **text**: Text/foreground color  
- **contrast_ratio**: Numerical contrast ratio
- **compliance_level**: WCAG compliance level

## Palette Filtering

### Filter by Theme

Separate colors in a palette by their theme characteristics:

```crystal
full_palette = [
  PrismatIQ::RGB.new(255, 255, 255), # Light
  PrismatIQ::RGB.new(0, 0, 0),       # Dark
  PrismatIQ::RGB.new(240, 240, 240), # Light
  PrismatIQ::RGB.new(30, 30, 30),    # Dark
]

light_colors = detector.filter_for_light_theme(full_palette)
dark_colors = detector.filter_for_dark_theme(full_palette)

puts "Light colors: #{light_colors.map(&.to_hex)}"
puts "Dark colors: #{dark_colors.map(&.to_hex)}"
```

### Palette Analysis

Categorize an entire palette by theme:

```crystal
analysis = detector.analyze_palette(full_palette)
puts "Dark colors: #{analysis[:dark].size}"
puts "Light colors: #{analysis[:light].size}"

# Find dominant theme
dominant = detector.dominant_theme(full_palette)
puts "Dominant theme: #{dominant}"
```

## Dual Theme Generation

### Generate Complete Light/Dark Theme Palettes

Create comprehensive dual-theme systems from a source palette:

```crystal
source = [
  PrismatIQ::RGB.new(100, 150, 200), # Primary brand color
  PrismatIQ::RGB.new(50, 100, 150),  # Secondary brand color  
]

dual = detector.generate_dual_themes(source, WCAGLevel::AA)

if dual
  puts "Light theme background: #{dual.light.background.to_hex}"
  puts "Light theme primary: #{dual.light.primary.to_hex}"
  puts "Dark theme background: #{dual.dark.background.to_hex}"  
  puts "Dark theme primary: #{dual.dark.primary.to_hex}"
end
```

The `DualThemePalette` contains complete `TextColorPalette` objects for both light and dark themes, ensuring consistent branding across theme variants.

## Advanced Usage Patterns

### Theme-Aware Applications

Build applications that automatically adapt to detected themes:

```crystal
def configure_ui_for_image(path)
  # Extract dominant color from image
  result = PrismatIQ.get_palette_v2(path, Options.new(color_count: 1))
  return unless result.ok?
  
  dominant = result.value.first
  
  # Detect theme and generate appropriate UI colors
  detector = PrismatIQ::ThemeDetector.new
  theme = detector.detect_theme(dominant)
  
  case theme
  when :light
    ui_config = {
      background: dominant,
      text: detector.suggest_foreground(dominant),
      accent: adjust_saturation(dominant, 1.2)
    }
  when :dark
    ui_config = {
      background: dominant,
      text: detector.suggest_foreground(dominant), 
      accent: adjust_brightness(dominant, 1.3)
    }
  end
  
  apply_ui_config(ui_config)
end
```

### Batch Theme Analysis

Process multiple images for theme consistency:

```crystal
def analyze_theme_consistency(image_paths)
  detector = PrismatIQ::ThemeDetector.new
  themes = [] of Symbol
  
  image_paths.each do |path|
    result = PrismatIQ.get_palette_v2(path, Options.new(color_count: 1))
    if result.ok?
      dominant = result.value.first
      themes << detector.detect_theme(dominant)
    end
  end
  
  light_count = themes.count { |t| t == :light }
  dark_count = themes.count { |t| t == :dark }
  
  if light_count > dark_count
    puts "Predominantly light-themed content"
  elsif dark_count > light_count  
    puts "Predominantly dark-themed content"
  else
    puts "Balanced theme distribution"
  end
end
```

## Caching and Performance

The `ThemeDetector` uses intelligent caching to improve performance:

- **Theme detection results** are cached per RGB color
- **Luminance calculations** are cached and shared with accessibility calculations
- **Palette analysis results** benefit from cached individual color detections

### Cache Management

```crystal
# Clear all cached values
detector.clear_cache

# Cache is automatically used on subsequent calls  
theme1 = detector.detect_theme(color)
theme2 = detector.detect_theme(color)  # Returns cached value
```

### Thread Safety

Each `ThemeDetector` instance is completely thread-safe:

```crystal
detector = PrismatIQ::ThemeDetector.new

# Safe to use concurrently from multiple fibers
100.times do |i|
  spawn do
    color = PrismatIQ::RGB.new(i % 256, (i * 2) % 256, (i * 3) % 256)
    theme = detector.detect_theme(color)
    # Process theme...
  end
end
```

## Integration with Accessibility

Theme detection works seamlessly with accessibility calculations:

```crystal
detector = PrismatIQ::ThemeDetector.new
calculator = PrismatIQ::AccessibilityCalculator.new

background = PrismatIQ::RGB.new(240, 240, 240)

# Generate theme-appropriate palette
palette = detector.suggest_text_palette(background, WCAGLevel::AAA)

# Verify compliance with accessibility calculator
primary_ok = calculator.wcag_aaa_compliant?(palette.primary, background)
secondary_ok = calculator.wcag_aa_compliant?(palette.secondary, background)

puts "Primary meets AAA: #{primary_ok}"
puts "Secondary meets AA: #{secondary_ok}"
```

This combination ensures that your applications provide both aesthetically appropriate and accessibility-compliant color schemes.