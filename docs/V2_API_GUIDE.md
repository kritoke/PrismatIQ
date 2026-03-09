# PrismatIQ v2 API Documentation

## Overview

PrismatIQ has been modernized with a new Result-based API (v2) that provides better error handling, thread safety, and memory optimization. This guide covers the new API and migration path from the legacy API.

## Table of Contents

1. [Quick Start](#quick-start)
2. [New v2 API](#new-v2-api)
3. [Thread Safety](#thread-safety)
4. [Memory Optimization](#memory-optimization)
5. [Migration Guide](#migration-guide)
6. [API Reference](#api-reference)

## Quick Start

### Basic Usage (v2 API)

```crystal
require "prismatiq"

# Simple palette extraction
result = PrismatIQ.get_palette_v2("image.png")

if result.ok?
  colors = result.value
  colors.each do |color|
    puts color.to_hex # => "#FF5733"
  end
else
  error = result.error
  puts "Error: #{error.message}"
  puts "Type: #{error.type}"
  puts "Context: #{error.context}"
end
```

### With Options

```crystal
options = PrismatIQ::Options.new(
  color_count: 8,
  quality: 5,
  threads: 4
)

result = PrismatIQ.get_palette_v2("image.png", options)
```

### Raising Variant

```crystal
# Raises on error
begin
  colors = PrismatIQ.get_palette_v2!("image.png")
rescue ex : Exception
  puts "Failed: #{ex.message}"
end
```

## New v2 API

### Result Types

The v2 API uses `Result(T, E)` types for explicit error handling:

```crystal
# Success case
result = PrismatIQ.get_palette_v2("valid.png")
# => Result::Ok(Array(RGB))

# Error case
result = PrismatIQ.get_palette_v2("missing.png")
# => Result::Err(Error)
```

### Error Struct

All errors are structured with type, message, and context:

```crystal
struct Error
  getter type : ErrorType      # Error classification
  getter message : String       # Human-readable message
  getter context : Hash(String, String)?  # Additional context
end

enum ErrorType
  FileNotFound        # File doesn't exist
  InvalidImagePath    # Path validation failed
  UnsupportedFormat   # Image format not supported
  CorruptedImage      # Image data is corrupt
  InvalidOptions      # Parameter validation failed
  ProcessingFailed    # General processing error
end
```

### Error Examples

```crystal
# File not found
result = PrismatIQ.get_palette_v2("nonexistent.png")
if result.err?
  error = result.error
  error.type        # => ErrorType::FileNotFound
  error.message     # => "File not found: nonexistent.png"
  error.context     # => {"path" => "nonexistent.png"}
end

# Invalid options
options = PrismatIQ::Options.new(color_count: 0)
result = PrismatIQ.get_palette_v2("image.png", options)
if result.err?
  error = result.error
  error.type        # => ErrorType::InvalidOptions
  error.message     # => "Invalid color_count: must be >= 1"
  error.context     # => {"field" => "color_count", "value" => "0"}
end
```

## Thread Safety

### Instance-Based Caching

The new API provides thread-safe classes with instance-based caching:

#### AccessibilityCalculator

```crystal
# Old way (NOT thread-safe)
# Uses global class variables
ratio = PrismatIQ::Accessibility.contrast_ratio(fg, bg)

# New way (thread-safe)
# Each instance has isolated cache
calculator = PrismatIQ::AccessibilityCalculator.new
ratio = calculator.contrast_ratio(fg, bg)

# Clear cache when done
calculator.clear_cache
```

#### ThemeDetector

```crystal
# Old way (NOT thread-safe)
# Uses global class variables
theme = PrismatIQ::Theme.detect(color)

# New way (thread-safe)
# Each instance has isolated cache
detector = PrismatIQ::ThemeDetector.new
theme = detector.detect_theme(color)

# Analyze palette
analysis = detector.analyze_palette(palette)
# => {:dark => [...], :light => [...]}

# Clear cache when done
detector.clear_cache
```

### Concurrent Access

The new classes are safe for concurrent access:

```crystal
detector = PrismatIQ::ThemeDetector.new

# Safe to use across multiple fibers
100.times do |i|
  spawn do
    color = colors[i]
    theme = detector.detect_theme(color)
    # Thread-safe!
  end
end
```

## Memory Optimization

### Histogram Pooling

The library now uses object pooling to reduce memory allocation:

```crystal
# Before: Allocated histograms per thread
# 16 threads = 16 × 32KB = 512KB always

# After: Reusable pool
# Pool maintains 2× thread count histograms
# Typical usage: 25-40% memory reduction
```

### Adaptive Processing

Processing automatically adapts to image size:

```crystal
# Small images (<100K pixels)
# - Single thread (no overhead)
# - 32KB memory

# Medium images (100K-1M pixels)
# - 2-4 threads
# - 64-128KB memory

# Large images (>1M pixels)
# - Up to 8 threads
# - 256KB memory (pooled)
```

### Performance Characteristics

| Image Size | Before | After | Improvement |
|------------|--------|-------|-------------|
| Small (<100K) | 512KB | 32KB | **-94%** |
| Medium (1M) | 512KB | 256KB | **-50%** |
| Large (10M) | 512KB | 384KB | **-25%** |

## Migration Guide

### Phase 1: Non-Breaking (v0.6.0)

The new v2 API is added alongside the existing API. Both work:

```crystal
# Old API (still works)
colors = PrismatIQ.get_palette("image.png", options)

# New API (recommended)
result = PrismatIQ.get_palette_v2("image.png", options)
```

### Migration Steps

#### Step 1: Update to v2 API

```crystal
# Before
colors = PrismatIQ.get_palette("image.png")
# Returns: Array(RGB)
# Errors: Returns [RGB.new(0,0,0)] on error

# After
result = PrismatIQ.get_palette_v2("image.png")
if result.ok?
  colors = result.value
else
  error = result.error
  # Handle error properly
end
```

#### Step 2: Update Options

```crystal
# Before
colors = PrismatIQ.get_palette("image.png", 8, 5, 4)

# After
options = PrismatIQ::Options.new(
  color_count: 8,
  quality: 5,
  threads: 4
)
colors = PrismatIQ.get_palette_v2!("image.png", options)
```

#### Step 3: Update Error Handling

```crystal
# Before
colors = PrismatIQ.get_palette("image.png")
if colors == [RGB.new(0,0,0)]
  puts "Error occurred"
end

# After
result = PrismatIQ.get_palette_v2("image.png")
if result.err?
  error = result.error
  case error.type
  when .file_not_found?
    puts "File not found: #{error.context["path"]}"
  when .corrupted_image?
    puts "Corrupted image: #{error.message}"
  else
    puts "Error: #{error.message}"
  end
end
```

#### Step 4: Update Thread-Sensitive Code

```crystal
# Before (not thread-safe)
# Global state could cause race conditions
PrismatIQ::Accessibility.clear_cache

# After (thread-safe)
calculator = PrismatIQ::AccessibilityCalculator.new
# Use instance, no global state
```

### Phase 2: Deprecation (v0.7.0)

Old methods will emit deprecation warnings:

```
Warning: Deprecated PrismatIQ.get_palette(path, color_count, quality, threads)
Use PrismatIQ.get_palette_v2(path, options) instead
```

### Phase 3: Removal (v0.8.0)

Old methods will be removed:

- `get_palette(path, color_count, quality, threads)` - **REMOVED**
- `PaletteResult` struct - **REMOVED**
- Sentinel error value `[RGB.new(0,0,0)]` - **REMOVED**

## API Reference

### Core Methods

#### `get_palette_v2(path, options) : Result(Array(RGB), Error)`

Extract color palette from an image file.

**Parameters:**
- `path : String` - Path to image file
- `options : Options` - Extraction options (optional)

**Returns:** `Result(Array(RGB), Error)`

**Errors:**
- `FileNotFound` - File doesn't exist
- `InvalidImagePath` - Path validation failed
- `UnsupportedFormat` - Format not supported
- `CorruptedImage` - Image data is corrupt

**Example:**
```crystal
result = PrismatIQ.get_palette_v2("image.png")
```

#### `get_palette_v2!(path, options) : Array(RGB)`

Extract palette, raising on error.

**Parameters:**
- `path : String` - Path to image file
- `options : Options` - Extraction options (optional)

**Returns:** `Array(RGB)`

**Raises:** `Exception` on any error

**Example:**
```crystal
colors = PrismatIQ.get_palette_v2!("image.png")
```

#### `get_palette_v2(io, options) : Result(Array(RGB), Error)`

Extract palette from an IO stream.

**Parameters:**
- `io : IO` - Input stream
- `options : Options` - Extraction options (optional)

**Returns:** `Result(Array(RGB), Error)`

**Example:**
```crystal
File.open("image.png") do |file|
  result = PrismatIQ.get_palette_v2(file)
end
```

#### `get_palette_v2(pixels, width, height, options, config) : Result(Array(RGB), Error)`

Extract palette from raw RGBA pixels.

**Parameters:**
- `pixels : Slice(UInt8)` - RGBA pixel data
- `width : Int32` - Image width
- `height : Int32` - Image height
- `options : Options` - Extraction options (optional)
- `config : Config` - Runtime config (optional)

**Returns:** `Result(Array(RGB), Error)`

**Example:**
```crystal
pixels = Slice(UInt8).new(width * height * 4) { |i| rand(256).to_u8 }
result = PrismatIQ.get_palette_v2(pixels, width, height)
```

### Options Struct

```crystal
struct Options
  property color_count : Int32        # Number of colors (1-256)
  property quality : Int32             # Quality setting (1-100)
  property threads : Int32             # Thread count (0 = auto)
  property alpha_threshold : UInt8     # Alpha threshold (0-255)
  
  def initialize(
    @color_count = 5,
    @quality = 10,
    @threads = 0,
    @alpha_threshold = 128_u8
  )
  end
  
  def validate! : Nil
    # Raises ValidationError if invalid
  end
end
```

### AccessibilityCalculator Class

Thread-safe accessibility calculations.

```crystal
class AccessibilityCalculator
  def initialize
  end
  
  def relative_luminance(rgb : RGB) : Float64
  end
  
  def contrast_ratio(fg : RGB, bg : RGB) : Float64
  end
  
  def wcag_level(fg : RGB, bg : RGB, large_text = false) : WCAGLevel
  end
  
  def wcag_aa_compliant?(fg : RGB, bg : RGB) : Bool
  end
  
  def compliance_report(fg : RGB, bg : RGB) : ComplianceReport
  end
  
  def clear_cache : Nil
  end
end
```

### ThemeDetector Class

Thread-safe theme detection.

```crystal
class ThemeDetector
  def initialize
  end
  
  def detect_theme(color : RGB) : Symbol
    # => :dark or :light
  end
  
  def detect_theme_info(color : RGB) : ThemeInfo
  end
  
  def is_dark?(color : RGB) : Bool
  end
  
  def is_light?(color : RGB) : Bool
  end
  
  def suggest_foreground(bg : RGB) : RGB
  end
  
  def suggest_background(fg : RGB) : RGB
  end
  
  def analyze_palette(palette : Array(RGB)) : Hash(Symbol, Array(RGB))
  end
  
  def dominant_theme(palette : Array(RGB)) : Symbol
  end
  
  def clear_cache : Nil
  end
end
```

## Best Practices

### 1. Use Result Types

Always handle both success and error cases:

```crystal
result = PrismatIQ.get_palette_v2("image.png")
case result
when .ok?
  colors = result.value
  # Process colors
when .err?
  error = result.error
  # Handle error
end
```

### 2. Instance-Based Classes

Create instances for thread-safe operations:

```crystal
# Good: Thread-safe
calculator = PrismatIQ::AccessibilityCalculator.new
ratio = calculator.contrast_ratio(fg, bg)

# Avoid in multi-threaded contexts:
# Uses global state
ratio = PrismatIQ::Accessibility.contrast_ratio(fg, bg)
```

### 3. Clear Caches

Clear caches when done to free memory:

```crystal
calculator = PrismatIQ::AccessibilityCalculator.new
# ... use calculator ...
calculator.clear_cache
```

### 4. Validate Options

Let the library validate options:

```crystal
# Automatic validation
result = PrismatIQ.get_palette_v2("image.png", options)
if result.err? && result.error.type.invalid_options?
  # Handle invalid options
end
```

## Changelog

### v0.6.0 (Current)

**Added:**
- Result-based v2 API (`get_palette_v2`, `get_palette_v2!`)
- `AccessibilityCalculator` class for thread-safe accessibility
- `ThemeDetector` class for thread-safe theme detection
- `HistogramPool` for memory optimization
- `AdaptiveChunkSizer` for optimal processing
- Comprehensive input validation
- Structured Error types with context
- 40 new tests (262 total)

**Security:**
- Eliminated all shell command execution
- Added path traversal prevention
- Added file size limits (100MB)
- Sanitized error messages

**Performance:**
- 25-40% memory reduction
- Adaptive parallel processing
- Instance-based caching

**Deprecated:**
- `get_palette(path, color_count, quality, threads)` - Use `get_palette_v2(path, options)`
- `PaletteResult` struct - Use `Result(Array(RGB), Error)`
- Global accessibility/theme methods - Use instance-based classes

### v0.7.0 (Planned)

- Deprecation warnings for old API
- Additional Result-returning methods
- Enhanced error messages

### v0.8.0 (Planned)

- Remove deprecated methods
- Remove `PaletteResult` struct
- Remove sentinel error values

## Support

For questions or issues:
- GitHub Issues: [project-url]/issues
- Documentation: [project-url]/docs
- Examples: [project-url]/examples
