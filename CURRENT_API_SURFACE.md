# Current Public API Surface (Pre-Refactor)

**Date:** March 8, 2026  
**Version:** 0.4.1  

## Main Public Methods

### Palette Extraction

#### `get_palette` (Multiple Overloads)
```crystal
def self.get_palette(path : String, options : Options = Options.default) : Array(RGB)
def self.get_palette(io : IO, options : Options = Options.default) : Array(RGB)
def self.get_palette(img, options : Options = Options.default) : Array(RGB)
def self.get_palette(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default, config : Config = Config.default) : Array(RGB)
def self.get_palette_from_image(image, options : Options, config : Config = Config.default) : Array(RGB)
def self.get_palette_from_buffer(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options, config : Config = Config.default) : Array(RGB)
def self.get_palette_from_buffer(pixels : Slice(UInt8), width : Int32, height : Int32, color_count : Int32 = 5, quality : Int32 = 10, threads : Int32 = 0, config : Config = Config.default) : Array(RGB)
```

**Return Type:** `Array(RGB)`  
**Error Handling:** Returns `[RGB.new(0, 0, 0)]` on error (sentinel value)

#### `get_palette_result` (Multiple Overloads)
```crystal
def self.get_palette_result(path : String, options : Options = Options.default) : PaletteResult
def self.get_palette_result(io : IO, options : Options = Options.default) : PaletteResult
def self.get_palette_result(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default, config : Config = Config.default) : PaletteResult
```

**Return Type:** `PaletteResult` (custom struct)  
**Error Handling:** Returns PaletteResult with ok=false and error message

#### `get_palette_or_error` (Multiple Overloads)
```crystal
def self.get_palette_or_error(path : String, options : Options = Options.default) : Result(Array(RGB), String)
def self.get_palette_or_error(io : IO, options : Options = Options.default) : Result(Array(RGB), String)
def self.get_palette_or_error(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default, config : Config = Config.default) : Result(Array(RGB), String)
```

**Return Type:** `Result(Array(RGB), String)`  
**Error Handling:** Returns `Result::Err(String)` with error message

### Async Methods

#### `get_palette_async`
```crystal
def self.get_palette_async(path : String, options : Options = Options.default, &block : Array(RGB) ->)
```

**Return Type:** None (callback-based)  
**Error Handling:** Unknown (need to check implementation)

#### `get_palette_channel`
```crystal
def self.get_palette_channel(path : String, options : Options = Options.default) : Channel(Array(RGB))
```

**Return Type:** `Channel(Array(RGB))`  
**Error Handling:** Unknown (need to check implementation)

### Utility Methods

#### `find_closest`
```crystal
def self.find_closest(target : RGB, palette : Array(RGB)) : RGB?
def self.find_closest_in_palette(target : RGB, path : String, options : Options = Options.default) : RGB?
```

**Return Type:** `RGB?` (nilable)

#### `get_color`
```crystal
def self.get_color(path : String) : RGB
def self.get_color(io : IO) : RGB
def self.get_color(img) : RGB
```

**Return Type:** `RGB`  
**Error Handling:** Unknown

#### `get_palette_with_stats`
```crystal
def self.get_palette_with_stats(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default, config : Config = Config.default) : Tuple(Array(PaletteEntry), Int32)
```

**Return Type:** `Tuple(Array(PaletteEntry), Int32)`

#### `get_palette_color_thief`
```crystal
def self.get_palette_color_thief(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default) : Array(String)
```

**Return Type:** `Array(String)`

## Supporting Types

### Structs
- `RGB` - Red, Green, Blue color values
- `Options` - Configuration options (color_count, quality, threads)
- `Config` - Internal configuration
- `PaletteResult` - Custom result type with ok/value/error fields
- `PaletteEntry` - Palette entry with color and count

### Enums
- None visible in public API

### Modules
- `PrismatIQ::Accessibility` - Accessibility helpers (contrast, luminance)
- `PrismatIQ::Theme` - Theme detection (dark/light)

## Error Handling Approaches

**Currently Mixed:**
1. **Sentinel values:** `[RGB.new(0, 0, 0)]` in `get_palette` methods
2. **Custom result type:** `PaletteResult` struct
3. **Standard Result:** `Result(Array(RGB), String)` in `get_palette_or_error`
4. **Unknown:** Async methods (need investigation)

## File Structure (Current)

```
src/
  prismatiq.cr (989 lines - main file with everything)
  cpu_cores.cr (CPU detection via shell commands)
  prismatiq/
    accessibility.cr
    theme.cr
    config.cr
    options.cr
    result.cr
    rgb.cr
    yiq_converter.cr
    color_extractor.cr
    thread_safe_cache.cr
    tempfile_helper.cr
    bmp_parser.cr
    ico/
      (ICO parsing modules)
```

## Test Coverage

**Current:** ~60% edge case coverage  
**Test Count:** 222 examples  
**Test Status:** All passing (0 failures)

## Known Issues

1. **Shell command execution:** CPU detection uses backticks
2. **Global state:** Accessibility/Theme modules use class variables
3. **Mixed concurrency:** Thread.new and spawn mixed
4. **Fixed memory allocation:** 32KB histogram per thread regardless of image size
5. **Sentinel error values:** Ambiguous with legitimate black pixels

## Breaking Changes Planned

### Phase 1 (v0.6.0) - Non-Breaking
- Add new Result-returning methods
- Add deprecation warnings
- Module extraction (internal)

### Phase 2 (v0.7.0) - Breaking
- Remove deprecated method overloads
- Remove PaletteResult struct
- Remove sentinel error values
- Standardize on Result types

### Phase 3 (v0.8.0) - Polish
- Performance optimization
- Memory optimization
- Final cleanup
