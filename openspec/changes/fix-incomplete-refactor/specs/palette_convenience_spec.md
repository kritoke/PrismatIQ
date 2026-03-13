# Specification: PaletteConvenience Class

## Overview

The `PaletteConvenience` class provides high-level convenience methods for palette extraction with additional features like statistics, async operations, and compatibility wrappers.

## Class Definition

```crystal
module PrismatIQ
  module Core
    class PaletteConvenience
      def initialize(@config : Config = Config.default)
      end
    end
  end
end
```

## Methods

### get_palette_channel

**Signature:**
```crystal
def get_palette_channel(path : String, options : Options = Options.default) : Channel(Array(RGB))
```

**Purpose:** Provides fiber-based asynchronous palette extraction using Crystal channels.

**Behavior:**
- Creates a buffered channel with capacity 1
- Spawns a fiber to perform the extraction
- Sends the extracted palette through the channel
- Closes the channel after sending
- On error, sends `[RGB.new(0, 0, 0)]` as a fallback (NOTE: this should be improved to proper error handling)
- Returns immediately, allowing caller to receive from channel when ready

**Example:**
```crystal
convenience = Core::PaletteConvenience.new
ch = convenience.get_palette_channel("image.jpg", options)
palette = ch.receive  # Blocks until extraction is complete
```

**Thread Safety:** Safe to call from multiple fibers concurrently.

### get_palette_with_stats

**Signature:**
```crystal
def get_palette_with_stats(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default) : Tuple(Array(PaletteEntry), Int32)
```

**Purpose:** Extracts a color palette with detailed statistics including pixel counts and percentages.

**Behavior:**
- Extracts palette using underlying `PaletteExtractor`
- Builds histogram to determine pixel counts for each color
- Calculates percentage of total pixels for each color
- Returns tuple of `(entries, total_pixels)`

**Return Value:**
- First element: `Array(PaletteEntry)` where each entry has:
  - `rgb : RGB` - the extracted color
  - `count : Int32` - number of pixels matching this color
  - `percent : Float64` - percentage of total pixels (0.0 to 1.0)
- Second element: `Int32` - total number of pixels processed

**Example:**
```crystal
entries, total = convenience.get_palette_with_stats(pixels, width, height, options)
entries.each do |entry|
  puts "#{entry.rgb.to_hex}: #{entry.count} pixels (#{(entry.percent * 100).round(1)}%)"
end
```

**Edge Cases:**
- If no valid pixels (all transparent), returns empty array and 0
- Percentages are based on total_pixels, not total image pixels
- Counts may not sum to total_pixels due to quantization

### get_palette_color_thief

**Signature:**
```crystal
def get_palette_color_thief(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default) : Array(String)
```

**Purpose:** Provides ColorThief-compatible output format (array of hex color strings).

**Behavior:**
- Extracts palette using underlying `PaletteExtractor`
- Converts each `RGB` to hex string format (e.g., "#ff8000")
- Returns array ordered by dominance (most common first)

**Return Value:** `Array(String)` of hex color codes

**Example:**
```crystal
colors = convenience.get_palette_color_thief(pixels, width, height, options)
# => ["#e74c3c", "#2ecc71", "#3498db", "#f39c12", "#9b59b6"]
```

**Compatibility:** Matches ColorThief library output format for easy migration.

### get_color_from_path

**Signature:**
```crystal
def get_color_from_path(path : String) : RGB
```

**Purpose:** Extracts a single dominant color from an image file.

**Behavior:**
- Creates options with `color_count: 1`
- Extracts palette from file path
- Returns first (most dominant) color
- Returns `RGB.new(0, 0, 0)` as fallback on error (NOTE: should be improved)

**Return Value:** Single `RGB` struct

**Example:**
```crystal
dominant = convenience.get_color_from_path("logo.png")
puts dominant.to_hex  # => "#ff6b35"
```

### get_color_from_io

**Signature:**
```crystal
def get_color_from_io(io : IO) : RGB
```

**Purpose:** Extracts a single dominant color from an IO stream.

**Behavior:**
- Creates options with `color_count: 1`
- Extracts palette from IO
- Returns first (most dominant) color
- Returns `RGB.new(0, 0, 0)` as fallback on error

**Return Value:** Single `RGB` struct

**Example:**
```crystal
File.open("image.jpg") do |file|
  dominant = convenience.get_color_from_io(file)
end
```

### get_color (generic)

**Signature:**
```crystal
def get_color(img) : RGB
```

**Purpose:** Extracts a single dominant color from various image sources.

**Behavior:**
- Accepts `CrImage::Image`, `String` (path), or `IO`
- Delegates to appropriate specialized method
- Returns `RGB.new(0, 0, 0)` as fallback on error

**Return Value:** Single `RGB` struct

**Example:**
```crystal
# From path
color1 = convenience.get_color("image.jpg")

# From IO
File.open("image.jpg") { |f| color2 = convenience.get_color(f) }

# From CrImage::Image
img = CrImage.read("image.jpg")
color3 = convenience.get_color(img)
```

## Dependencies

The `PaletteConvenience` class depends on:
- `PaletteExtractor` - for core extraction logic
- `Options` - for configuration
- `Config` - for runtime behavior (debug, threading)
- `RGB` - for color representation
- `PaletteEntry` - for statistics output
- `YIQConverter` - for color space conversion

## Thread Safety

All methods in `PaletteConvenience` are thread-safe:
- No shared mutable state in the class itself
- Delegates to thread-safe `PaletteExtractor`
- Channel-based async is inherently thread-safe

## Performance Considerations

- `get_palette_with_stats` requires two passes: histogram build + extraction
- `get_palette_channel` has overhead of fiber creation
- Consider caching results if calling repeatedly on same image

## Error Handling

Current implementation uses fallback values (`RGB.new(0, 0, 0)`) for errors. This should be improved to:
- Raise exceptions for critical errors
- Return `Result` types for recoverable errors
- Provide meaningful error messages

## Testing Requirements

### Unit Tests Required

1. **get_palette_channel**
   - Test successful async extraction
   - Test error handling (invalid path)
   - Test channel is properly closed
   - Test concurrent calls

2. **get_palette_with_stats**
   - Test with known test image
   - Verify counts and percentages are correct
   - Test with transparent images
   - Test with single-color images
   - Test percentages sum to approximately 1.0

3. **get_palette_color_thief**
   - Test hex format is correct
   - Test order is by dominance
   - Test with various color counts
   - Test compatibility with ColorThief format

4. **get_color variants**
   - Test from path
   - Test from IO
   - Test from CrImage::Image
   - Test error cases

### Integration Tests Required

- Test all methods work together
- Test with real images of various formats
- Test performance with large images
- Test thread safety under load

## Migration Notes

This class replaces the previous inline implementations that were scattered across the codebase. Users should not notice any API changes as the public `PrismatIQ` module methods delegate to this class transparently.
