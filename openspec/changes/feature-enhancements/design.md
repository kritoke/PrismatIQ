# Design: Feature Enhancements

**Change:** feature-enhancements
**Date:** Feb 25, 2026

## 1. Result Type / Custom Errors

### Current State
Methods return `[RGB.new(0, 0, 0)]` on failure, making it impossible to distinguish between actual black and errors.

### Proposed Design
```crystal
module PrismatIQ
  # Result type for palette extraction
  struct PaletteResult
    getter colors : Array(RGB)
    getter success : Bool
    getter error : String?
    getter total_pixels : Int32

    def self.ok(colors : Array(RGB), total_pixels : Int32) : PaletteResult
      new(colors, true, nil, total_pixels)
    end

    def self.err(message : String) : PaletteResult
      new([] of RGB, false, message, 0)
    end
  end

  # Add new methods that return PaletteResult
  def self.get_palette_result(path : String, ...) : PaletteResult
  end
end
```

### Migration Path
- Keep existing methods for backward compatibility
- Add new `get_palette_result` methods
- Deprecate old methods in next major version

---

## 2. Configuration Struct

### Current State
Methods have many individual parameters: `color_count`, `quality`, `threads`, etc.

### Proposed Design
```crystal
module PrismatIQ
  struct Options
    property color_count : Int32 = 5
    property quality : Int32 = 10
    property threads : Int32 = 0  # 0 = auto
    property alpha_threshold : UInt8 = 125_u8
    
    def validate!
      raise ValidationError.new("color_count must be >= 1") if @color_count < 1
      raise ValidationError.new("quality must be >= 1") if @quality < 1
    end
  end

  # New API
  def self.get_palette(path : String, options : Options = Options.new) : Array(RGB)
    options.validate!
    # ...
  end
end
```

### Migration Path
- Add overloaded methods accepting `Options`
- Keep existing method signatures for backward compatibility

---

## 3. Color Distance / Matching API

### Proposed Design
```crystal
module PrismatIQ
  struct RGB
    # Calculate perceptual distance using CIEDE2000 or simple Euclidean
    def distance_to(other : RGB) : Float64
      # Simple Euclidean in RGB space
      Math.sqrt((@r - other.r)**2 + (@g - other.g)**2 + (@b - other.b)**2)
    end

    # Convert to LAB for perceptual distance
    def to_lab : Tuple(Float64, Float64, Float64)
      # RGB -> XYZ -> LAB conversion
    end
  end

  # Find closest color in palette
  def self.find_closest(target : RGB, palette : Array(RGB)) : RGB
    palette.min_by(&.distance_to(target))
  end

  # Find closest color from image
  def self.find_closest_in_palette(target : RGB, path : String, options : Options = Options.new) : RGB
    palette = get_palette(path, options)
    find_closest(target, palette)
  end
end
```

---

## 4. JSON/YAML Serialization

### Proposed Design
```crystal
module PrismatIQ
  struct RGB
    include JSON::Serializable
    include YAML::Serializable

    property r : Int32
    property g : Int32
    property b : Int32

    # Custom serialization to hex
    def to_json(builder : JSON::Builder)
      builder.string(to_hex)
    end

    def self.from_json(pull : JSON::PullParser) : RGB
      hex = pull.read_string
      # Parse hex to RGB
    end
  end

  struct PaletteEntry
    include JSON::Serializable
    include YAML::Serializable
  end
end
```

---

## 5. Fiber-based Async API

### Proposed Design
```crystal
module PrismatIQ
  # Async palette extraction using fibers
  def self.get_palette_async(path : String, options : Options = Options.new, &block : Array(RGB) ->) : Void
    spawn do
      result = get_palette(path, options)
      block.call(result)
    end
  end

  # Using Channel for result delivery
  def self.get_palette_channel(path : String, options : Options = Options.new) : Channel(Array(RGB))
    ch = Channel(Array(RGB)).new(1)
    spawn do
      ch.send(get_palette(path, options))
    end
    ch
  end
end
```

---

## 6. WCAG Contrast Checker

### Proposed Design
```crystal
module PrismatIQ
  module Accessibility
    # Calculate relative luminance (WCAG 2.0)
    def self.relative_luminance(rgb : RGB) : Float64
      r = rgb.r / 255.0
      g = rgb.g / 255.0
      b = rgb.b / 255.0
      
      r = r <= 0.03928 ? r / 12.92 : ((r + 0.055) / 1.055) ** 2.4
      g = g <= 0.03928 ? g / 12.92 : ((g + 0.055) / 1.055) ** 2.4
      b = b <= 0.03928 ? b / 12.92 : ((b + 0.055) / 1.055) ** 2.4
      
      0.2126 * r + 0.7152 * g + 0.0722 * b
    end

    # Calculate contrast ratio between two colors (WCAG 2.0)
    def self.contrast_ratio(foreground : RGB, background : RGB) : Float64
      l1 = relative_luminance(foreground)
      l2 = relative_luminance(background)
      lighter = {l1, l2}.max
      darker = {l1, l2}.min
      (lighter + 0.05) / (darker + 0.05)
    end

    # Check WCAG AA compliance (4.5:1 for normal text)
    def self.wcag_aa_compliant?(foreground : RGB, background : RGB) : Bool
      contrast_ratio(foreground, background) >= 4.5
    end

    # Check WCAG AAA compliance (7:1 for normal text)
    def self.wcag_aaa_compliant?(foreground : RGB, background : RGB) : Bool
      contrast_ratio(foreground, background) >= 7.0
    end
  end
end
```

---

## 7. Caching Layer

### Proposed Design
```crystal
module PrismatIQ
  module Cache
    @@cache = {} of String => CacheEntry
    @@enabled = false
    @@ttl = 300_seconds

    struct CacheEntry
      property palette : Array(RGB)
      property timestamp : Time
    end

    def self.enable(ttl : Time::Span = 300_seconds) : Void
      @@enabled = true
      @@ttl = ttl
    end

    def self.disable : Void
      @@enabled = false
    end

    def self.clear : Void
      @@cache.clear
    end

    def self.get_cached(path : String, options : Options) : Array(RGB)?
      return nil unless @@enabled
      key = cache_key(path, options)
      entry = @@cache[key]?
      return nil unless entry
      return nil if Time.utc - entry.timestamp > @@ttl
      entry.palette
    end

    private def self.cache_key(path : String, options : Options) : String
      "#{path}:#{options.color_count}:#{options.quality}"
    end
  end
end
```

## Implementation Order
1. Options struct (enables cleaner API for all other features)
2. PaletteResult type (backward compatible)
3. JSON/YAML serialization (simple addition)
4. Color distance API (self-contained)
5. WCAG contrast checker (self-contained)
6. Fiber async API (self-contained)
7. Caching layer (optional, can be added later)
