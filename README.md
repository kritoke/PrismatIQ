# PrismatIQ

A high-performance Crystal shard for extracting dominant color palettes from images using the YIQ color space. This is a port of the Color Thief logic (MMCQ) but optimized for Crystal's performance and perception-based color math.

## Features

- **Color Palette Extraction**: Extract dominant colors from any image format
- **SVG Support**: Extract colors directly from SVG vector graphics (no rasterization needed)
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
result = PrismatIQ.get_palette("image.png", options)
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
  colors = PrismatIQ.get_palette!("image.png", options)
  colors.each { |color| puts color.to_hex }
rescue ex : Exception
  puts "Failed to extract palette: #{ex.message}"
end

# Or use exception-based API for simpler cases
begin
  colors = PrismatIQ.get_palette!("image.png", options)
  colors.each { |color| puts color.to_hex }
rescue ex : Exception
  puts "Failed: #{ex.message}"
end
```

### Theme Extraction API

```crystal
# Extract theme from local file
theme = PrismatIQ.extract_theme("favicon.ico")
if theme
  puts "Background: #{theme.bg}"
  puts "Light text: #{theme.text["light"]}"
  puts "Dark text: #{theme.text["dark"]}"
  puts "JSON: #{theme.to_json}"
end

# Extract theme from URL
theme = PrismatIQ.extract_theme("https://example.com/favicon.ico")

# Auto-correct theme for accessibility compliance
original_theme = "{\"bg\":\"#808080\",\"text\":{\"light\":\"#aaaaaa\",\"dark\":\"#555555\"}}"
fixed_theme = PrismatIQ.fix_theme(original_theme)

# Clear the cache
PrismatIQ.clear_theme_cache
```

### ICO File Support

```crystal
result = PrismatIQ.get_palette_from_ico("icon.ico", options)
if result.ok?
  # Process extracted palette
end
```

### Single Color Extraction

```crystal
dominant = PrismatIQ.get_color("image.png")
puts dominant.to_hex  # => "#e74c3c"
```

### SVG Color Extraction

```crystal
# Extract colors from SVG string
svg_content = %(<svg><rect fill="#FF0000"/><circle fill="rgb(0,255,0)"/></svg>)
colors = PrismatIQ::SVGColorExtractor.extract_colors(svg_content)
colors.each { |color| puts color.to_hex }

# Extract colors from SVG file
result = PrismatIQ::SVGColorExtractor.extract_from_file("icon.svg")
case result
when .ok?
  colors = result.value
  colors.each { |color| puts color.to_hex }
when .err?
  error = result.error
  puts "Error: #{error.message}"
end
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

## Examples

- **[ColorThief Adapter](./examples/color_thief_adapter.cr)** - CLI that produces ColorThief-compatible JSON output
- **Basic usage examples** in [examples/README.md](./examples/README.md)

## Version

Current library version: `0.5.3`

## Security Considerations

### SSRF Protection

When using the `ThemeExtractor` to fetch images from URLs, PrismatIQ includes built-in **Server-Side Request Forgery (SSRF) protection**:

- **Private IP Blocking**: Requests to private/reserved IP ranges are blocked by default:
  - IPv4: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `127.0.0.0/8`, `169.254.0.0/16`, `0.0.0.0/8`
  - IPv6: `::1/128`, `fc00::/7`, `fe80::/10`
- **URL Scheme Validation**: Only `http://` and `https://` URLs are allowed
- **DNS Rebinding Protection**: IP addresses are resolved and validated before connection

### Configuration

SSRF protection is **enabled by default**. To customize:

```crystal
# Disable SSRF protection (not recommended)
config = PrismatIQ::Config.new(ssrf_protection: false)

# Allow specific internal hosts via allowlist
config = PrismatIQ::Config.new(
  ssrf_protection: true,
  ssrf_allowlist: ["internal.company.com", "localhost"]
)
```

Or via environment variables:
```bash
export PRISMATIQ_SSRF_PROTECTION=false  # Disable (not recommended)
export PRISMATIQ_SSRF_ALLOWLIST=internal.company.com,localhost
```

### Path Validation

When extracting from local files, PrismatIQ validates:
- **Path Traversal**: Blocks `..` and URL-encoded variants (`%2e%2e`, `%252e%252e`)
- **Null Byte Injection**: Rejects paths containing `\0`
- **System Directories**: Prevents access to `/etc/`, `/sys/`, `/proc/`
- **File Size Limits**: Enforces 100MB maximum file size

### Debug Mode

When `PRISMATIQ_DEBUG=true` is set, all caught exceptions are logged to STDERR. This may include sensitive information (URLs, file paths) - use only during development.