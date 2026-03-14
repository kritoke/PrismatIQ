# API Reference

This document provides a complete reference of all public APIs available in PrismatIQ v0.5.0.

## Palette Extraction APIs

### `PrismatIQ.get_palette_v2(path, options)` 
- **Parameters**: 
  - `path : String` - Path to image file
  - `options : Options = Options.default` - Extraction configuration
- **Returns**: `Result(Array(RGB), Error)`
- **Description**: Extract dominant colors from an image file with explicit error handling using structured Error types.

### `PrismatIQ.get_palette_v2!(path, options)`
- **Parameters**: 
  - `path : String` - Path to image file  
  - `options : Options = Options.default` - Extraction configuration
- **Returns**: `Array(RGB)`
- **Raises**: `Exception` or `ValidationError` on errors
- **Description**: Extract dominant colors from an image file, raising exceptions on errors for simpler error handling.

### `PrismatIQ.get_palette_v2(io, options)`
- **Parameters**:
  - `io : IO` - IO object containing image data
  - `options : Options = Options.default` - Extraction configuration  
- **Returns**: `Result(Array(RGB), Error)`
- **Description**: Extract palette from an IO source with explicit error handling.

### `PrismatIQ.get_palette_v2!(io, options)`
- **Parameters**:
  - `io : IO` - IO object containing image data
  - `options : Options = Options.default` - Extraction configuration
- **Returns**: `Array(RGB)`
- **Raises**: `Exception` or `ValidationError` on errors
- **Description**: Extract palette from an IO source, raising exceptions on errors.

### `PrismatIQ.get_palette_v2(pixels, width, height, options, config)`
- **Parameters**:
  - `pixels : Slice(UInt8)` - RGBA pixel data (4 bytes per pixel)
  - `width : Int32` - Image width in pixels
  - `height : Int32` - Image height in pixels  
  - `options : Options = Options.default` - Extraction configuration
  - `config : Config = Config.default` - Runtime configuration
- **Returns**: `Result(Array(RGB), Error)`
- **Description**: Extract palette from raw RGBA buffer with explicit error handling.

### `PrismatIQ.get_palette_v2!(pixels, width, height, options, config)`
- **Parameters**:
  - `pixels : Slice(UInt8)` - RGBA pixel data (4 bytes per pixel)
  - `width : Int32` - Image width in pixels
  - `height : Int32` - Image height in pixels
  - `options : Options = Options.default` - Extraction configuration  
  - `config : Config = Config.default` - Runtime configuration
- **Returns**: `Array(RGB)`
- **Raises**: `Exception` or `ValidationError` on errors
- **Description**: Extract palette from raw RGBA buffer, raising exceptions on errors.

### `PrismatIQ.get_palette_from_ico_v2(path, options)`
- **Parameters**:
  - `path : String` - Path to ICO file
  - `options : Options = Options.default` - Extraction configuration
- **Returns**: `Result(Array(RGB), Error)`
- **Description**: Extract palette from Windows ICO files (supports both PNG and BMP encoded icons) with explicit error handling.

### `PrismatIQ.get_palette_from_buffer(pixels, width, height, options, config)`
- **Parameters**:
  - `pixels : Slice(UInt8)` - RGBA pixel data
  - `width : Int32` - Image width  
  - `height : Int32` - Image height
  - `options : Options` - Extraction configuration (required)
  - `config : Config = Config.default` - Runtime configuration
- **Returns**: `Array(RGB)`
- **Description**: Buffer-based extraction returning array directly (no Result wrapper). This is the foundation method used by other APIs.

### `PrismatIQ.get_color(path)` / `get_color(io)` / `get_color(img)`
- **Parameters**: Image source (path, IO, or CrImage::Image)
- **Returns**: `RGB`
- **Description**: Convenience methods to extract just the single dominant color.

### `PrismatIQ.get_palette_with_stats(pixels, width, height, options, config)`
- **Parameters**: Same as buffer-based extraction
- **Returns**: `Tuple(Array(PaletteEntry), Int32)`
- **Description**: Returns detailed statistics including color counts and percentages.

### `PrismatIQ.get_palette_color_thief(pixels, width, height, options)`
- **Parameters**: Same as buffer-based extraction  
- **Returns**: `Array(String)`
- **Description**: Returns hex color strings in ColorThief-compatible format.

## Utility Methods

### `PrismatIQ.find_closest(target, palette)`
- **Parameters**:
  - `target : RGB` - Target color to match
  - `palette : Array(RGB)` - Array of candidate colors
- **Returns**: `RGB?`
- **Description**: Find the closest matching color from a palette using Euclidean distance in RGB space.

### `PrismatIQ.find_closest_in_palette(target, path, options)`
- **Parameters**:
  - `target : RGB` - Target color to match  
  - `path : String` - Path to image file
  - `options : Options = Options.default` - Extraction configuration
- **Returns**: `RGB?`
- **Description**: Extract palette from image and find closest matching color to target.

## Async APIs

### `PrismatIQ.get_palette_channel(path, options)`
- **Parameters**:
  - `path : String` - Path to image file
  - `options : Options = Options.default` - Extraction configuration  
- **Returns**: `Channel(Array(RGB))`
- **Description**: Non-blocking palette extraction using Crystal fibers and channels.

## Core Classes

### `PrismatIQ::Options`
Configuration struct for palette extraction parameters:
- `color_count : Int32` - Number of colors to extract (default: 5)
- `quality : Int32` - Sampling quality, lower = better quality (default: 10)  
- `threads : Int32` - Worker threads, 0 = auto-detect (default: 0)
- `alpha_threshold : UInt8` - Alpha cutoff for transparent pixels (default: 125)

### `PrismatIQ::Config`
Runtime configuration for debugging and performance:
- `debug : Bool` - Enable debug output (default: false)
- `threads : Int32?` - Override detected thread count
- `merge_chunk : Int32?` - Override histogram merge chunk size

### `PrismatIQ::Error`
Structured error type with:
- `type : ErrorType` - Error category enum
- `message : String` - Human-readable message  
- `context : Hash(String, String)?` - Additional context information

### `PrismatIQ::Result(T, E)`
Result type inspired by Rust's Result:
- `ok?` / `err?` - Check success/failure
- `value` / `error` - Get result value or error
- `value_or(default)` - Get value or default
- `map`, `flat_map`, `map_error` - Functional transformations

### `PrismatIQ::AccessibilityCalculator`
Instance-based accessibility calculations with caching.

### `PrismatIQ::ThemeDetector`  
Instance-based theme detection with caching.

### `PrismatIQ::RGB`
Color representation with utility methods:
- `to_hex` / `from_hex` - Hex string conversion
- `distance_to(other)` - Euclidean distance calculation
- JSON/YAML serialization support