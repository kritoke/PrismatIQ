# PrismatIQ
A high-performance Crystal shard for extracting dominant color palettes from images using the YIQ color space. This is a port of the Color Thief logic (MMCQ) but optimized for Crystal's performance and perception-based color math.

## Features

- **Color Palette Extraction**: Extract dominant colors from any image format
- **WCAG Accessibility**: Built-in WCAG contrast checking and color adjustment
- **Theme Detection**: Automatic dark/light theme detection and color pairing
- **ICO Support**: Extract palettes from Windows icon files (PNG and BMP encoded)
- **Multi-threaded**: Parallel histogram building for improved performance
- **Caching**: Intelligent caching for frequently-used calculations
- **Error Handling**: Explicit error handling with Result types

## Getting started
 - Install shards: `shards install`
 - Run tests: `crystal spec`

 ColorThief-like example
 - Example CLI that produces a ColorThief-compatible JSON payload is at `examples/color_thief_adapter.cr`.
 - Usage: `crystal run examples/color_thief_adapter.cr -- path/to/image.jpg [count] [quality] [threads]`
   - `count` (optional): number of colors to return (default 5)
   - `quality` (optional): sampling step (default 10). Lower is higher fidelity, higher is faster.
   - `threads` (optional): number of worker threads for histogram build (default 0 = auto)

  APIs of interest
  - `PrismatIQ.get_palette_from_buffer(pixels, width, height, color_count = 5, quality = 10, threads = 0)`
    - Returns `Array(PrismatIQ::RGB)` like ColorThief's palette (but as structs).
  - `PrismatIQ.get_palette_with_stats_from_buffer(pixels, width, height, color_count = 5, quality = 10, threads = 0)`
    - Returns `[Array(PrismatIQ::PaletteEntry), Int32]` where `PaletteEntry` has `rgb`, `count`, and `percent`.
  - `PrismatIQ.get_palette_color_thief_from_buffer(...)`
    - Convenience wrapper that returns `Array(String)` of hex colors (dominant first) to match ColorThief consumers.
  - `PrismatIQ.get_palette_from_ico(path, ...)` 
    - Extract palette from ICO files, returns `[RGB.new(0,0,0)]` on error
  - `PrismatIQ.get_palette_from_ico_or_error(path, ...)`
    - Robust ICO extraction returning `Result(Array(RGB), String)` for explicit error handling

  Error Handling with Result Type
  - `PrismatIQ.get_palette_or_error(path, options)` returns `Result(Array(RGB), String)` for explicit error handling.
  - `PrismatIQ.get_palette_from_ico_or_error(path, options)` returns `Result(Array(RGB), String)` for ICO files.
  - `Result` provides: `ok?`, `err?`, `value`, `error`, `value_or`, `map`, `flat_map`, `map_error`

  Configuration
 - `PrismatIQ::Config` struct for runtime settings:
   - `debug : Bool` - enable debug traces
   - `threads : Int32?` - override thread count
   - `merge_chunk : Int32?` - override merge chunk size
 - Use `Config.default` for environment-based config, or create explicitly:

   ```crystal
   config = PrismatIQ::Config.new(debug: true, threads: 4)
   colors = PrismatIQ.get_palette("image.png", options, config: config)
   ```

 Testing with Config
 - Pass `Config.new(debug: true)` to enable debug output without setting ENV vars:
   ```crystal
   it "extracts colors" do
     config = PrismatIQ::Config.new(debug: false)
     colors = PrismatIQ.get_palette("test.png", color_count: 3, config: config)
     colors.size.should eq(3)
   end
   ```

  Environment knobs
  - `PRISMATIQ_THREADS`: override default thread detection
  - `PRISMATIQ_MERGE_CHUNK`: override merge chunk size (for histogram merging)
  - `PRISMATIQ_DEBUG`: enable debug traces

  ## WCAG Accessibility
  
  PrismatIQ includes comprehensive WCAG 2.0/2.1 accessibility support for checking and ensuring color contrast compliance.
  
  ### Basic Compliance Checking
  ```crystal
  # Check contrast ratio between two colors
  fg = PrismatIQ::RGB.new(50, 50, 50)
  bg = PrismatIQ::RGB.new(255, 255, 255)
  ratio = PrismatIQ::Accessibility.contrast_ratio(fg, bg)
  puts "Contrast ratio: #{ratio}:1"
  
  # Check WCAG compliance
  PrismatIQ::Accessibility.wcag_aa_compliant?(fg, bg)   # => true
  PrismatIQ::Accessibility.wcag_aaa_compliant?(fg, bg)  # => false
  
  # Get compliance level
  level = PrismatIQ::Accessibility.wcag_level(fg, bg)
  puts level # => WCAGLevel::AA
  ```
  
  ### Large Text Support
  WCAG has different requirements for large text (18pt+ or 14pt bold):
  ```crystal
  # Large text requires 3:1 for AA, 4.5:1 for AAA
  level = PrismatIQ::Accessibility.wcag_level(fg, bg, large_text: true)
  compliant = PrismatIQ::Accessibility.wcag_aa_large_compliant?(fg, bg)
  ```
  
  ### Compliance Reports
  Get detailed compliance information:
  ```crystal
  report = PrismatIQ::Accessibility.compliance_report(fg, bg)
  puts report.contrast_ratio        # => 12.63
  puts report.normal_text_level     # => WCAGLevel::AAA
  puts report.large_text_level      # => WCAGLevel::AAA
  puts report.recommendations.first # => "Excellent! This combination meets..."
  ```
  
  ### Auto-Fixing Non-Compliant Colors
  Automatically adjust colors to meet WCAG standards:
  ```crystal
  # Light gray text on white background (non-compliant)
  bad_fg = PrismatIQ::RGB.new(200, 200, 200)
  bg = PrismatIQ::RGB.new(255, 255, 255)
  
  # Auto-adjust to meet AA standard
  adjusted = PrismatIQ::Accessibility.adjust_for_compliance(bad_fg, bg, PrismatIQ::WCAGLevel::AA)
  puts adjusted.to_hex # => "#6e6e6e" (now compliant)
  ```
  
  ### Palette Analysis
  Check entire color palettes for compliance:
  ```crystal
  palette = PrismatIQ.get_palette("image.jpg", color_count: 8)
  bg = PrismatIQ::RGB.new(255, 255, 255)
  
  # Check all colors
  entries = PrismatIQ::Accessibility.check_palette_compliance(palette, bg)
  entries.each do |entry|
    puts "#{entry.color.to_hex}: #{entry.contrast_ratio}:1 - #{entry.compliant ? "✓" : "✗"}"
  end
  
  # Filter to only compliant colors
  compliant = PrismatIQ::Accessibility.filter_compliant(palette, bg, PrismatIQ::WCAGLevel::AA)
  ```
  
  ### Text Color Recommendations
  Get smart text color suggestions:
  ```crystal
  # Recommend black or white text for any background
  bg = PrismatIQ::RGB.new(100, 150, 200)
  text_color = PrismatIQ::Accessibility.recommend_text_color(bg, PrismatIQ::WCAGLevel::AA)
  puts text_color.to_hex # => "#000000" or "#ffffff"
  ```

  ## Theme Detection and Pairing
  
  Automatically detect theme type and generate compliant color schemes.
  
  ### Theme Detection
  ```crystal
  # Detect if a color is light or dark theme
  bg = PrismatIQ::RGB.new(240, 240, 240)
  theme = PrismatIQ::Theme.detect_theme(bg)
  puts theme # => :light
  
  # Get detailed theme info
  info = PrismatIQ::Theme.analyze_theme(bg)
  puts info.type                 # => :light
  puts info.luminance            # => 0.88
  puts info.perceived_brightness # => 0.94
  ```
  
  ### Complete Text Palettes
  Generate full text color palettes (primary, secondary, accent):
  ```crystal
  bg = PrismatIQ::RGB.new(50, 50, 50) # Dark background
  palette = PrismatIQ::Theme.suggest_text_palette(bg, PrismatIQ::WCAGLevel::AA)
  
  puts "Primary:   #{palette.primary.to_hex}"   # Main text color
  puts "Secondary: #{palette.secondary.to_hex}" # Muted text
  puts "Accent:    #{palette.accent.to_hex}"    # Links, highlights
  puts "Theme:     #{palette.theme_type}"       # :dark or :light
  ```
  
  ### Best Color Pairs
  Find the best background/text combinations from a palette:
  ```crystal
  palette = PrismatIQ.get_palette("website.jpg", color_count: 8)
  
  # Find all compliant pairs
  pairs = PrismatIQ::Theme.find_best_pairs(palette, PrismatIQ::WCAGLevel::AA)
  pairs.first(3).each do |pair|
    puts "BG: #{pair.background.to_hex} + Text: #{pair.text.to_hex}"
    puts "  Contrast: #{pair.contrast_ratio}:1 (#{pair.compliance_level})"
  end
  ```
  
  ### Theme Filtering
  Filter palettes by theme type:
  ```crystal
  # Get only light colors from palette
  light_colors = PrismatIQ::Theme.filter_for_light_theme(palette)
  
  # Get only dark colors from palette
  dark_colors = PrismatIQ::Theme.filter_for_dark_theme(palette)
  ```
  
  ### Dual Theme Generation
  Generate both light and dark theme palettes from a single source:
  ```crystal
  source = PrismatIQ.get_palette("brand.jpg", color_count: 6)
  dual = PrismatIQ::Theme.generate_dual_themes(source, PrismatIQ::WCAGLevel::AA)
  
  puts "Light theme:"
  puts "  Primary: #{dual.light.primary.to_hex}"
  puts "  BG:      #{dual.light.background.to_hex}"
  
  puts "Dark theme:"
  puts "  Primary: #{dual.dark.primary.to_hex}"
  puts "  BG:      #{dual.dark.background.to_hex}"
  ```

  ## ICO File Support
  
  Extract color palettes from Windows ICO (icon) files.
  
  ### Basic Usage
  ```crystal
  # Extract palette from favicon
  palette = PrismatIQ.get_palette_from_ico("favicon.ico", color_count: 5)
  palette.each { |color| puts color.to_hex }
  ```
  
  ### Supported Formats
  - PNG-encoded ICO entries (modern, preferred)
  - BMP/DIB formats: 1bpp, 4bpp, 8bpp, 24bpp, 32bpp
  - Bitfield compression for 16bpp and 32bpp
  - AND mask transparency
  
  ### Advanced Usage
  ```crystal
  # With custom parameters
  palette = PrismatIQ.get_palette_from_ico(
    "app.ico",
    color_count: 8,  # Extract 8 colors
    quality: 5,      # Higher quality
    threads: 4       # Multi-threaded processing
  )
  ```
  
  ### Error Handling
  ```crystal
  # Robust error handling with Result type
  result = PrismatIQ.get_palette_from_ico_or_error("icon.ico")
  if result.ok?
    palette = result.value
    palette.each { |color| puts color.to_hex }
  else
    puts "Error: #{result.error}"
  end
  
  # Convenience API (returns sentinel [RGB.new(0,0,0)] on error)
  palette = PrismatIQ.get_palette_from_ico("icon.ico")
  if palette.size == 1 && palette[0].r == 0
    puts "Warning: Could not extract meaningful palette"
  end
  ```

 Notes
 - Tests exercise determinism across thread counts and compatibility with ColorThief-like output.
 - The library quantizes into 5 bits per Y/I/Q axis (32³ = 32768 histogram slots).

Example output
 - The adapter emits a small JSON payload. Example (pretty-printed) output:

```json
{
  "colors": ["#e74c3c", "#2ecc71", "#3498db"],
  "entries": [
    { "hex": "#e74c3c", "count": 1200, "percent": 0.6 },
    { "hex": "#2ecc71", "count": 500,  "percent": 0.25 },
    { "hex": "#3498db", "count": 300,  "percent": 0.15 }
  ],
  "total_pixels": 2000
}
```

This format makes it easy to consume the dominant palette (the `colors` array) while
also exposing counts and percentages for richer UI or analytics use-cases.

Version
 - Current library version: `0.4.0` (see `src/prismatiq.cr`)

Changelog
 - See `CHANGELOG.md` for a concise list of unreleased and past changes.

Release notes / maintaining the changelog
 - When preparing a release: bump the `VERSION` constant in `src/prismatiq.cr` and
   add an entry to `CHANGELOG.md` under a new heading for the release (version + date).

CI
 - A GitHub Actions workflow is included at `.github/workflows/ci.yml` that runs specs
   and executes the example against the bundled sample image.

Warning
  - This is version 0.4.0. The code has automated tests and the library is
    ready for production use. Validate results for your dataset and consider
    pinning to a released version.

Additional notes
 - Multithreaded histogram building with per-thread locals and chunked merging to
   improve performance and cache locality on multi-core machines.
 - Adaptive merge chunk sizing that attempts to use CPU L2 cache sizing when available
   (probe via sysctl or sysfs), with an environment override via `PRISMATIQ_MERGE_CHUNK`.
 - Public APIs for buffer-based extraction (suitable for server code that already has
   an image buffer) and helpers to return ColorThief-like hex arrays for easy adoption.
 - Benchmarks and micro-bench scripts are included in the `bench/` folder to help
   tune parameters (merge chunk, thread count, quality) on your target hardware.
 - The MMCQ implementation was adjusted to include deterministic tie-breaking so
   results are stable across different thread counts and runs.

If you rely on this library for production, please open an issue with sample images
that cause problems so we can improve robustness.
