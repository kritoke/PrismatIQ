# Configuration

PrismatIQ provides flexible configuration through two main structs: `Options` for extraction parameters and `Config` for runtime behavior.

## Options Struct

The `Options` struct controls palette extraction behavior and should be used with all public APIs.

### Default Values

```crystal
options = PrismatIQ::Options.new
# Equivalent to:
options = PrismatIQ::Options.new(
  color_count: 5,      # Number of colors to extract
  quality: 10,         # Sampling quality (lower = better quality)
  alpha_threshold: 125 # Alpha cutoff for transparent pixels
)
```

### Parameter Details

#### `color_count : Int32`
- **Range**: 1 - 256
- **Default**: 5
- **Description**: Number of dominant colors to extract from the image
- **Validation**: Raises `ValidationError` if < 1 or > 256

#### `quality : Int32`
- **Range**: 1 - 100+
- **Default**: 10
- **Description**: Sampling quality where lower values = higher fidelity but slower processing
- **Behavior**: Controls how many pixels are sampled (every Nth pixel)
- **Validation**: Raises `ValidationError` if < 1

#### `alpha_threshold : UInt8`
- **Range**: 0 - 255
- **Default**: 125
- **Description**: Alpha channel cutoff for determining transparent pixels
- **Behavior**: Pixels with alpha < threshold are ignored in palette extraction

### Creating Options

#### Constructor Pattern

```crystal
# Basic usage
options = PrismatIQ::Options.new(color_count: 8)

# Full configuration
options = PrismatIQ::Options.new(
  color_count: 10,
  quality: 5,
  alpha_threshold: 128
)
```

#### Builder Pattern

```crystal
# Start with defaults and modify
options = PrismatIQ::Options.default
                .with_color_count(8)
                .with_quality(5)

# Or chain from new instance
options = PrismatIQ::Options.new.with_color_count(6).with_quality(3)
```

### Validation

Options are automatically validated when passed to extraction APIs:

```crystal
# This will raise ValidationError
bad_options = PrismatIQ::Options.new(color_count: 0)
result = PrismatIQ.get_palette_v2("image.png", bad_options)

# Handle validation errors explicitly
begin
  options.validate!
rescue ex : PrismatIQ::ValidationError
  puts "Invalid options: #{ex.message}"
end
```

## Config Struct

The `Config` struct controls runtime behavior like debugging, image dimension limits, and security settings.

### Default Values

```crystal
config = PrismatIQ::Config.new
# Equivalent to:
config = PrismatIQ::Config.new(
  debug: false,            # Disable debug output
  max_image_width: 8192,   # Max image width in pixels
  max_image_height: 8192   # Max image height in pixels
)
```

### Parameter Details

#### `debug : Bool`
- **Default**: false
- **Description**: Enable detailed debug output to STDERR
- **Output includes**: Processing steps, timing information, internal state

#### `max_image_width : Int32`
- **Default**: 8192
- **Description**: Maximum image width in pixels. Images exceeding this are rejected before RGBA conversion.
- **Validation**: Clamped to minimum of 1 if a value < 1 is provided

#### `max_image_height : Int32`
- **Default**: 8192
- **Description**: Maximum image height in pixels. Images exceeding this are rejected before RGBA conversion.
- **Validation**: Clamped to minimum of 1 if a value < 1 is provided

#### `ssrf_protection : Bool`
- **Default**: true
- **Description**: Enable SSRF protection for HTTP requests in theme extraction

#### `ssrf_allowlist : Array(String)?`
- **Default**: nil
- **Description**: List of hosts allowed to bypass SSRF protection

### Environment Variables

Config can also be controlled via environment variables:

- `PRISMATIQ_DEBUG=1` - Enable debug mode
- `PRISMATIQ_MAX_IMAGE_WIDTH=N` - Set max image width
- `PRISMATIQ_MAX_IMAGE_HEIGHT=N` - Set max image height
- `PRISMATIQ_SSRF_PROTECTION=false` - Disable SSRF protection
- `PRISMATIQ_SSRF_ALLOWLIST=host1,host2` - Set SSRF allowlist

### Usage Examples

#### Debug Mode

```crystal
config = PrismatIQ::Config.new(debug: true)
result = PrismatIQ.get_palette_v2(pixels, width, height, options, config)
# Outputs detailed processing information to STDERR
```

#### Image Dimension Limits

```crystal
config = PrismatIQ::Config.new(max_image_width: 4096, max_image_height: 4096)
result = PrismatIQ.get_palette_v2("image.png", options, config)
# Rejects images wider/taller than 4096px
```

#### Combining Options and Config

```crystal
options = PrismatIQ::Options.new(color_count: 8, quality: 3)
config = PrismatIQ::Config.new(debug: true)

result = PrismatIQ.get_palette_v2("image.png", options, config)
```

## Performance Tuning

### Quality vs Performance Trade-offs

| Quality | Description | Performance Impact |
|---------|-------------|-------------------|
| 1 | Sample every pixel | Slowest, highest accuracy |
| 5 | Sample every 5th pixel | Good balance |
| 10 | Sample every 10th pixel | Faster, good quality |
| 20+ | Sample every 20th+ pixel | Fastest, lower quality |

### Memory Optimization

PrismatIQ optimizes memory usage through:

- **Image dimension limits**: Configurable `max_image_width`/`max_image_height` (default 8192) reject oversized images before RGBA conversion
- **Bounded histogram iteration**: VBox computations iterate only the relevant histogram range instead of all 32,768 entries
- **Shared ThemeExtractor caching**: Module-level caching avoids per-call instance creation

## Best Practices

### 1. Always Use Options

Instead of relying on defaults, always create explicit `Options`:

```crystal
# Good - explicit and clear
options = PrismatIQ::Options.new(color_count: 5)
result = PrismatIQ.get_palette_v2(path, options)
```

### 2. Validate User Input

When accepting user-provided parameters, validate them before creating Options:

```crystal
def create_safe_options(user_color_count, user_quality)
  color_count = {user_color_count, 1}.max.clamp(1, 256)
  quality = {user_quality, 1}.max

  PrismatIQ::Options.new(color_count: color_count, quality: quality)
end
```

### 3. Use Environment-Based Config for Debugging

For development and debugging, use environment variables instead of hardcoded config:

```crystal
# In development, run with:
# PRISMATIQ_DEBUG=1 crystal run your_app.cr

# Your code uses default config:
result = PrismatIQ.get_palette_v2(path, options)
# Debug output appears only when PRISMATIQ_DEBUG=1
```

### 4. Set Image Dimension Limits for Untrusted Input

When processing user-uploaded images, set dimension limits to prevent memory spikes:

```crystal
config = PrismatIQ::Config.new(max_image_width: 4096, max_image_height: 4096)
result = PrismatIQ.get_palette_v2(uploaded_path, options, config)
```

### 5. Clear Caches Periodically

If processing many unique themes, clear caches to free memory:

```crystal
PrismatIQ.clear_caches
```

## Error Handling

Both `Options` and `Config` can cause validation errors:

### Options Validation Errors

- `color_count < 1` or `> 256`
- `quality < 1`

### Image Too Large Error

Images exceeding `max_image_width` or `max_image_height` return `ErrorType::ImageTooLarge`:

```crystal
result = PrismatIQ.get_palette_v2("huge.jpg", options)
if result.err? && result.error.type.image_too_large?
  puts "Image too large: #{result.error.message}"
end
```
