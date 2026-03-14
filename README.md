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

  ### New Options-based API (Recommended)

  The recommended way to call palette extraction is using the `Options` struct:

  ```crystal
  require "prismatiq"

  # Create options with desired parameters
  options = PrismatIQ::Options.new(
    color_count: 5,    # Number of colors to extract
    quality: 10,       # Sampling quality (1 = best, higher = faster)
    threads: 0,        # 0 = auto-detect, or specify thread count
    alpha_threshold: 125  # Alpha cutoff for transparent pixels
  )

  # Extract palette from file path
  palette = PrismatIQ.get_palette("image.png", options)

  # Extract palette from IO
  # palette = PrismatIQ.get_palette(io, options)

  # Extract palette from raw RGBA buffer
  # palette = PrismatIQ.get_palette(pixels, width, height, options)

  # Work with the extracted colors
  palette.each { |color| puts color.to_hex }
  ```

  #### Using builder methods for Options

  The `Options` struct provides convenient builder methods to create modified copies:

  ```crystal
  # Start with defaults and modify specific values
  options = PrismatIQ::Options.default.with_color_count(8).with_quality(5)

  # Or use individual setters
  options = PrismatIQ::Options.new(color_count: 8)
  options = options.with_threads(4)
  ```

APIs of interest (with Options)
- `PrismatIQ.get_palette(path, options)` - Returns `Array(PrismatIQ::RGB)` 
- `PrismatIQ.get_palette_v2(path, options)` - Returns `Result(Array(RGB), Error)` with structured error handling
- `PrismatIQ.get_palette_v2!(path, options)` - Returns `Array(RGB)` or raises exception on error
- `PrismatIQ.get_palette(pixels, width, height, options)` - Buffer-based extraction
- `PrismatIQ.get_palette_with_stats(pixels, width, height, options)` - Returns `[Array(PrismatIQ::PaletteEntry), Int32]` where `PaletteEntry` has `rgb`, `count`, and `percent`.
- `PrismatIQ.get_palette_color_thief(pixels, width, height, options)` - Returns `Array(String)` of hex colors (dominant first)
- `PrismatIQ.get_palette_from_ico(path, options)` - Extract palette from ICO files, returns `[RGB.new(0,0,0)]` on error
- `PrismatIQ.get_palette_from_ico_or_error(path, options)` - Robust ICO extraction returning `Result(Array(RGB), String)`

  ### Async and Callback APIs

  For non-blocking palette extraction, PrismatIQ provides fiber-based async APIs:

  ```crystal
  require "prismatiq"

  options = PrismatIQ::Options.new(color_count: 5)

  # Fiber-based async with callback
  PrismatIQ.get_palette_async("image.png", options) do |palette|
    palette.each { |color| puts color.to_hex }
  end

  # Channel-based async for more control
  channel = PrismatIQ.get_palette_channel("image.png", options)
  palette = channel.receive
  ```

  ### Finding Closest Colors

  Find the closest matching color from a palette:

  ```crystal
  require "prismatiq"

  options = PrismatIQ::Options.new(color_count: 8)
  palette = PrismatIQ.get_palette("brand.jpg", options)

  # Find closest color to a target
  target = PrismatIQ::RGB.new(100, 150, 200)
  closest = PrismatIQ.find_closest(target, palette)
  puts closest.try(&.to_hex)

  # Or directly from an image
  closest = PrismatIQ.find_closest_in_palette(target, "brand.jpg", options)
  ```

  ### Single Color Extraction

  Convenience method for extracting just the dominant color:

  ```crystal
  require "prismatiq"

  # Get the single dominant color
  dominant = PrismatIQ.get_color("image.png")
  puts dominant.to_hex  # => "#e74c3c"
  ```

### Error Handling with Result Type (Recommended)

For explicit error handling, use the Result-based APIs:

```crystal
require "prismatiq"

# Create options
options = PrismatIQ::Options.new(color_count: 5)

# Use Result-returning methods for explicit error handling
result = PrismatIQ.get_palette_or_error("image.png", options)

if result.ok?
  colors = result.value
  colors.each { |color| puts color.to_hex }
else
  puts "Error: #{result.error}"
end

# You can also chain operations
result = PrismatIQ.get_palette_or_error("image.png", options)
           .map { |colors| colors.map(&.to_hex) }
```

### New v2 API with Error Struct (Recommended)

The latest version introduces `get_palette_v2` which returns a `Result(Array(RGB), Error)` with structured error information:

```crystal
require "prismatiq"

options = PrismatIQ::Options.new(color_count: 5)

# Get palette with structured error handling
result = PrismatIQ.get_palette_v2("image.png", options)

case result
when .ok?
  colors = result.value
  colors.each { |color| puts color.to_hex }
when .err?
  error = result.error
  puts "Error type: #{error.type}"
  puts "Message: #{error.message}"
  if error.context
    puts "Context: #{error.context}"
  end
end

# Or use the raising variant (throws exceptions on error)
begin
  colors = PrismatIQ.get_palette_v2!("image.png", options)
  colors.each { |color| puts color.to_hex }
rescue ex : Exception
  puts "Failed to extract palette: #{ex.message}"
end
```

The `Error` struct provides:
- `type` - One of: `FileNotFound`, `InvalidImagePath`, `UnsupportedFormat`, `CorruptedImage`, `InvalidOptions`, `ProcessingFailed`
- `message` - Human-readable error message
- `context` - Hash with additional context (file path, parameter values, etc.)
- `to_s` - String representation including all details

**Error Types and When They Occur:**
- `FileNotFound` - File doesn't exist or cannot be accessed
- `InvalidImagePath` - Path contains directory traversal (`..`), home directory (`~`), or system directories (`/etc`, `/proc`, `/sys`)
- `UnsupportedFormat` - File extension not in supported formats (`.png`, `.jpg`, `.jpeg`, `.gif`, `.bmp`, `.ico`, `.webp`, `.tiff`, `.tif`)
- `CorruptedImage` - File is empty, truncated, or contains invalid image data
- `InvalidOptions` - Options parameters are out of valid ranges (e.g., `color_count < 1` or `> 256`, `quality < 1` or `> 100`, negative `threads`)
- `ProcessingFailed` - Unexpected error during processing (out of memory, internal errors, etc.)

The `Result(T, E)` type provides:
- `ok?` / `err?` - Check success/failure
- `value` - Get the successful value (raises if error)
- `error` - Get the error message (raises if success)
- `value_or(default)` - Get value or default
- `map { |v| ... }` - Transform the successful value
- `flat_map { |v| ... }` - Chain Result-returning operations
- `map_error { |e| ... }` - Transform the error

Alternative: PaletteResult (legacy)
- `PrismatIQ.get_palette_result(path, options)` returns `PaletteResult` with `colors`, `success`, `error`, and `total_pixels` fields.
- **Note**: `PaletteResult` is deprecated. Use `Result(Array(RGB), Error)` instead.

  ### Configuration Options

  **Runtime Config** (`Config` struct) - For debugging and performance tuning:
  - `debug : Bool` - enable debug traces
  - `threads : Int32?` - override thread count
  - `merge_chunk : Int32?` - override merge chunk size

  Use `Config.default` for environment-based config, or create explicitly:

  ```crystal
  config = PrismatIQ::Config.new(debug: true, threads: 4)
  palette = PrismatIQ.get_palette("image.png", options, config: config)
  ```

  **Extraction Options** (`Options` struct) - For palette extraction parameters:
  - `color_count : Int32` - number of colors to extract (default: 5)
  - `quality : Int32` - sampling quality, lower = better quality (default: 10)
  - `threads : Int32` - number of worker threads, 0 = auto (default: 0)
  - `alpha_threshold : UInt8` - alpha cutoff for transparent pixels (default: 125)

  ```crystal
  options = PrismatIQ::Options.new(
    color_count: 8,
    quality: 5,
    threads: 4,
    alpha_threshold: 128
  )
  ```

  ### RGB Color Utilities

  The `RGB` struct provides utility methods for color manipulation:

  ```crystal
  require "prismatiq"

  # Create colors
  rgb = PrismatIQ::RGB.new(255, 100, 50)
  
  # Convert to hex
  rgb.to_hex  # => "#ff6432"

  # Parse from hex
  rgb = PrismatIQ::RGB.from_hex("#3498db")

  # Calculate color distance (Euclidean in RGB space)
  color1 = PrismatIQ::RGB.new(255, 0, 0)
  color2 = PrismatIQ::RGB.new(0, 255, 0)
  distance = color1.distance_to(color2)  # => ~361.0
  ```

  The `RGB` struct also supports JSON and YAML serialization:

  ```crystal
  require "json"
  require "yaml"

  rgb = PrismatIQ::RGB.new(255, 100, 50)
  rgb.to_json  # => "\"#ff6432\""
  ```

  ### Testing with Config and Options
  - Pass `Config.new(debug: true)` to enable debug output without setting ENV vars:
    ```crystal
    it "extracts colors" do
      config = PrismatIQ::Config.new(debug: false)
      options = PrismatIQ::Options.new(color_count: 3)
      palette = PrismatIQ.get_palette("test.png", options, config: config)
      palette.size.should eq(3)
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
  options = PrismatIQ::Options.new(color_count: 8)
  palette = PrismatIQ.get_palette("image.jpg", options)
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
  options = PrismatIQ::Options.new(color_count: 8)
  palette = PrismatIQ.get_palette("website.jpg", options)
  
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
  options = PrismatIQ::Options.new(color_count: 6)
  source = PrismatIQ.get_palette("brand.jpg", options)
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
  # Create options for extraction
  options = PrismatIQ::Options.new(color_count: 5)

  # Extract palette from favicon (returns [RGB.new(0,0,0)] on error)
  palette = PrismatIQ.get_palette_from_ico("favicon.ico", options)
  palette.each { |color| puts color.to_hex }
  ```

  ### Using Options (Recommended)
  ```crystal
  # With custom parameters
  options = PrismatIQ::Options.new(
    color_count: 8,  # Extract 8 colors
    quality: 5,      # Higher quality
    threads: 4       # Multi-threaded processing
  )
  palette = PrismatIQ.get_palette_from_ico("app.ico", options)
  ```

  ### Error Handling
  ```crystal
  # Robust error handling with Result type (recommended)
  options = PrismatIQ::Options.new(color_count: 5)
  result = PrismatIQ.get_palette_from_ico_or_error("icon.ico", options)
  if result.ok?
    palette = result.value
    palette.each { |color| puts color.to_hex }
  else
    puts "Error: #{result.error}"
  end
  
  # Alternative: sentinel value check (legacy)
  palette = PrismatIQ.get_palette_from_ico("icon.ico", PrismatIQ::Options.new)
  if palette.size == 1 && palette[0].r == 0
    puts "Warning: Could not extract meaningful palette"
  end
  ```

  ## Migration Guide

  This version introduces a new Options-based API for cleaner, more maintainable code.
  Legacy APIs are deprecated but still work. Here's how to migrate:

  ### Old API (Deprecated)
  ```crystal
  # Using positional arguments (deprecated)
  palette = PrismatIQ.get_palette("image.png", 5, 10)
  entries, total = PrismatIQ.get_palette_with_stats_from_buffer(pixels, width, height, 5, 10, 0)
  colors = PrismatIQ.get_palette_from_ico("favicon.ico", 5, 10, 0)
  
  # Old result handling (checking for nil or sentinel)
  result = PrismatIQ.get_palette_result("image.png", 5, 10)
  if result.success
    colors = result.colors
  end
  ```

  ### New API (Recommended)
  ```crystal
  # Using Options struct (recommended)
  options = PrismatIQ::Options.new(color_count: 5, quality: 10)
  palette = PrismatIQ.get_palette("image.png", options)

  # Or with builder methods
  options = PrismatIQ::Options.default.with_color_count(5).with_quality(10)
  entries, total = PrismatIQ.get_palette_with_stats(pixels, width, height, options)

  # ICO extraction
  options = PrismatIQ::Options.new(color_count: 5, quality: 10, threads: 0)
  colors = PrismatIQ.get_palette_from_ico("favicon.ico", options)
  ```

### Error Handling Migration

```crystal
# Old: Checking for sentinel value
palette = PrismatIQ.get_palette_from_ico("icon.ico", 5, 10, 0)
if palette.size == 1 && palette[0].r == 0
  puts "Error occurred"
end

# New: Using Result type (recommended)
options = PrismatIQ::Options.new(color_count: 5)
result = PrismatIQ.get_palette_from_ico_or_error("icon.ico", options)
if result.ok?
  puts "Success: #{result.value}"
else
  puts "Error: #{result.error}"
end

# Latest: Using v2 API with Error struct (recommended)
result = PrismatIQ.get_palette_v2("icon.ico", options)
case result
when .ok?
  puts "Success: #{result.value}"
when .err?
  puts "Error: #{result.error.message} (#{result.error.type})"
end

# Or use PaletteResult for legacy compatibility
result = PrismatIQ.get_palette_result("image.png", options)
if result.success
  colors = result.colors
end
```

  ### Async API Migration
  ```crystal
  # New: Fiber-based async extraction
  options = PrismatIQ::Options.new(color_count: 5)
  
  # Callback style
  PrismatIQ.get_palette_async("image.png", options) do |palette|
    puts palette
  end

  # Channel style
  ch = PrismatIQ.get_palette_channel("image.png", options)
  palette = ch.receive
  ```

### Why Migrate?
- **Single source of truth**: All parameters are in one place (`Options` struct)
- **Better extensibility**: Adding new parameters doesn't break existing code
- **Type safety**: Named parameters provide better compile-time checking
- **Explicit error handling**: Result type makes error cases explicit
- **Builder methods**: Easy to create modified options without verbose instantiation
- **Async support**: Native fiber-based async APIs for non-blocking operations
- **Performance**: Multi-threaded histogram building with adaptive cache-aware merging
- **Thread Safety**: Instance-based components with comprehensive thread safety guarantees

 Notes
 - Tests exercise determinism across thread counts and compatibility with ColorThief-like output.
 - The library quantizes into 5 bits per Y/I/Q axis (32³ = 32768 histogram slots).
 - **Comprehensive Documentation**: Use `crystal docs` to generate complete API documentation with thread safety and memory optimization details.
 - See the CHANGELOG.md for detailed migration instructions and deprecation timeline.

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
  - Current library version: `0.4.1` (see `src/prismatiq.cr`)

 Documentation
  - Run `crystal docs` to generate comprehensive API documentation
  - All public methods include detailed thread safety and usage information
  - Use `crystal docs --project-name PrismatIQ --api-path api` for hosted documentation

 Changelog
  - See `CHANGELOG.md` for a concise list of unreleased and past changes.

Release notes / maintaining the changelog
 - When preparing a release: bump the `VERSION` constant in `src/prismatiq.cr` and
   add an entry to `CHANGELOG.md` under a new heading for the release (version + date).

CI
 - A GitHub Actions workflow is included at `.github/workflows/ci.yml` that runs specs
   and executes the example against the bundled sample image.

Warning
  - This is version 0.4.1. The code has automated tests and the library is
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
