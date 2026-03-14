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
  threads: 0,          # Worker threads (0 = auto-detect)
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

#### `threads : Int32`
- **Range**: Any integer
- **Default**: 0 (auto-detect)
- **Description**: Number of worker threads for histogram building
- **Special values**:
  - `0`: Auto-detect based on image size and CPU cores
  - `1`: Force single-threaded processing  
  - `>1`: Use specified number of threads
- **Note**: Small images (<100K) automatically use single-threaded processing regardless of setting

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
  threads: 4,
  alpha_threshold: 128
)
```

#### Builder Pattern

```crystal
# Start with defaults and modify
options = PrismatIQ::Options.default
                .with_color_count(8)
                .with_quality(5)
                .with_threads(2)

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

The `Config` struct controls runtime behavior like debugging and threading overrides.

### Default Values

```crystal
config = PrismatIQ::Config.new
# Equivalent to:
config = PrismatIQ::Config.new(
  debug: false,        # Disable debug output
  threads: nil,        # Use default thread detection
  merge_chunk: nil     # Use default merge chunk size
)
```

### Parameter Details

#### `debug : Bool`
- **Default**: false
- **Description**: Enable detailed debug output to STDERR
- **Output includes**: Processing steps, timing information, internal state

#### `threads : Int32?`
- **Default**: nil (use automatic detection)
- **Description**: Override the automatic thread count detection
- **Usage**: Useful for testing or when you know the optimal thread count

#### `merge_chunk : Int32?`
- **Default**: nil (use automatic calculation)  
- **Description**: Override histogram merge chunk size
- **Advanced**: Only needed for fine-tuning performance on specific workloads

### Environment Variables

Config can also be controlled via environment variables:

- `PRISMATIQ_DEBUG=1` - Enable debug mode
- `PRISMATIQ_THREADS=N` - Set thread count override
- `PRISMATIQ_MERGE_CHUNK=N` - Set merge chunk size override

### Usage Examples

#### Debug Mode

```crystal
config = PrismatIQ::Config.new(debug: true)
result = PrismatIQ.get_palette_v2(pixels, width, height, options, config)
# Outputs detailed processing information to STDERR
```

#### Thread Override

```crystal
config = PrismatIQ::Config.new(threads: 8)
result = PrismatIQ.get_palette_v2("large_image.png", options, config)
# Forces 8 threads regardless of automatic detection
```

#### Combining Options and Config

```crystal
options = PrismatIQ::Options.new(color_count: 8, quality: 3)
config = PrismatIQ::Config.new(debug: true, threads: 4)

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

### Thread Count Guidelines

- **Small images** (< 100K pixels): Single-threaded is fastest
- **Medium images** (100K - 1M pixels): 2-4 threads optimal  
- **Large images** (> 1M pixels): 4-8 threads optimal
- **Auto-detection** (`threads: 0`) works well for most cases

### Memory Optimization

PrismatIQ automatically optimizes memory usage through:

- **Histogram pooling**: Reuses histogram objects (25-40% memory reduction)
- **Adaptive processing**: Uses single-threaded for small images
- **Chunked merging**: Optimized for CPU cache performance

These optimizations are automatic and don't require configuration.

## Best Practices

### 1. Always Use Options

Instead of relying on defaults, always create explicit `Options`:

```crystal
# ✅ Good - explicit and clear
options = PrismatIQ::Options.new(color_count: 5)
result = PrismatIQ.get_palette_v2(path, options)

# ❌ Avoid - unclear what parameters are being used
result = PrismatIQ.get_palette_v2(path)
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

### 4. Profile Before Optimizing

Use the default auto-detection settings first, then profile and optimize only if needed:

```crystal
# Start with defaults
options = PrismatIQ::Options.new(color_count: 5)

# Only optimize if profiling shows issues
if image_is_very_large?
  options = options.with_threads(8).with_quality(5)
end
```

## Error Handling

Both `Options` and `Config` can cause validation errors:

### Options Validation Errors

- `color_count < 1` or `> 256`
- `quality < 1`
- Invalid parameter combinations

### Config Validation

Config parameters are generally more flexible, but extreme values may cause processing failures that result in `ProcessingFailed` errors.

Always handle validation errors appropriately:

```crystal
begin
  options.validate!
  config.validate! # Not currently implemented but future-proof
  result = PrismatIQ.get_palette_v2(path, options, config)
rescue ex : PrismatIQ::ValidationError
  Log.error("Invalid configuration: #{ex.message}")
  # Use safe defaults or return error to user
end
```