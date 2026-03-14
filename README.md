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

## Getting Started

```bash
# Install shards
shards install

# Run tests  
crystal spec

# Build the library
crystal build src/prismatiq.cr -o prismatiq --release
```

## Quick Examples

### Basic Palette Extraction

```crystal
require "prismatiq"

# Create extraction options
options = PrismatIQ::Options.new(
  color_count: 5,
  quality: 10, 
  threads: 0
)

# Extract palette with explicit error handling (recommended)
result = PrismatIQ.get_palette_v2("image.png", options)
case result
when .ok?
  result.value.each { |color| puts color.to_hex }
when .err?
  puts "Error: #{result.error.message}"
end

# Or use exception-based API for simpler cases
begin
  colors = PrismatIQ.get_palette_v2!("image.png", options)
  colors.each { |color| puts color.to_hex }
rescue ex : Exception
  puts "Failed: #{ex.message}"
end
```

### ICO File Support

```crystal
result = PrismatIQ.get_palette_from_ico_v2("icon.ico", options)
if result.ok?
  # Process extracted palette
end
```

### Single Color Extraction

```crystal
dominant = PrismatIQ.get_color("image.png")
puts dominant.to_hex  # => "#e74c3c"
```

### Buffer-based Extraction

```crystal
# Extract from raw RGBA pixel data
pixels = Slice(UInt8).new(width * height * 4)
# ... populate pixels ...
palette = PrismatIQ.get_palette_from_buffer(pixels, width, height, options)
```

## Advanced Usage

For detailed documentation on specific features, see the guides:

- [API Reference](./API_REFERENCE.md) - Complete method reference
- [Error Handling](./ERROR_HANDLING.md) - Working with Result types and errors  
- [WCAG Accessibility](./ACCESSIBILITY_GUIDE.md) - Accessibility calculations and compliance
- [Theme Detection](./THEME_DETECTION.md) - Theme analysis and color pairing
- [Configuration](./CONFIGURATION.md) - Options and runtime configuration
- [Migration Guide](./MIGRATION.md) - Upgrading from v0.4.x to v0.5.0

## Examples

- **[ColorThief Adapter](./examples/color_thief_adapter.cr)** - CLI that produces ColorThief-compatible JSON output
- **Basic usage examples** in [examples/README.md](./examples/README.md)

## Version

Current library version: `0.5.0`