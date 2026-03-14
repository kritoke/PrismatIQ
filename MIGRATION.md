# Migration Guide: v0.4.x to v0.5.0

PrismatIQ v0.5.0 represents a clean break from previous versions with significant API improvements and removal of all deprecated functionality.

## Breaking Changes

### Complete Removal of Deprecated APIs

All v0.4.x deprecated APIs have been **completely removed**:

- **Old palette extraction methods**:
  - `PrismatIQ.get_palette(path, options)` → Use `get_palette_v2` or `get_palette_v2!`
  - `PrismatIQ.get_palette(io, options)` → Use `get_palette_v2` or `get_palette_v2!`
  - `PrismatIQ.get_palette_from_ico(path, options)` → Use `get_palette_from_ico_v2`

- **Positional parameter APIs** (removed in v0.4.1):
  - `get_palette(path, color_count, quality, threads)` 
  - All other APIs with positional parameters instead of `Options`

- **Module-level utility classes**:
  - `PrismatIQ::Accessibility` → Use `AccessibilityCalculator` instance
  - `PrismatIQ::Theme` → Use `ThemeDetector` instance

- **Legacy error handling**:
  - Sentinel error values `[RGB.new(0,0,0)]` → Structured `Result(Array(RGB), Error)`
  - `get_palette_or_error` → Use `get_palette_v2`

### New Requirements

- **All APIs require explicit error handling** through `Result` types or exceptions
- **Utility classes must be instantiated** (`AccessibilityCalculator.new`, `ThemeDetector.new`)
- **Buffer-based extraction** remains unchanged

## Migration Patterns

### 1. Palette Extraction

#### Before (v0.4.x)
```crystal
# Old method with sentinel error handling
colors = PrismatIQ.get_palette("image.png", options)
if colors == [RGB.new(0,0,0)]
  puts "Error occurred"
end

# Or using Result API
result = PrismatIQ.get_palette_or_error("image.png", options)
if result.ok?
  # handle success
else
  # handle error  
end
```

#### After (v0.5.0)
```crystal
# Result-based API (recommended)
result = PrismatIQ.get_palette_v2("image.png", options)
case result
when .ok?
  colors = result.value
  # handle success
when .err?
  puts "Error: #{result.error.message}"
  # handle structured error
end

# Exception-based API (simpler cases)
begin
  colors = PrismatIQ.get_palette_v2!("image.png", options)
  # handle success
rescue ex : Exception
  puts "Failed: #{ex.message}"
end
```

### 2. ICO File Support

#### Before (v0.4.x)
```crystal
# Old method
colors = PrismatIQ.get_palette_from_ico("icon.ico", options)

# Or Result API
result = PrismatIQ.get_palette_from_ico_or_error("icon.ico", options)
```

#### After (v0.5.0)
```crystal
# New v2 API
result = PrismatIQ.get_palette_from_ico_v2("icon.ico", options)
if result.ok?
  colors = result.value
end

# Or exception-based
colors = PrismatIQ.get_palette_from_ico_v2!("icon.ico", options)
```

### 3. Accessibility Calculations

#### Before (v0.4.x)
```crystal
# Module-level methods
lum = PrismatIQ::Accessibility.relative_luminance(color)
level = PrismatIQ::Accessibility.wcag_level(fg, bg)
palette = PrismatIQ::Theme.suggest_text_palette(background)
```

#### After (v0.5.0)
```crystal
# Instance-based classes
calculator = PrismatIQ::AccessibilityCalculator.new
detector = PrismatIQ::ThemeDetector.new

lum = calculator.relative_luminance(color)
level = calculator.wcag_level(fg, bg)
palette = detector.suggest_text_palette(background)
```

### 4. Buffer-Based Extraction (Unchanged)

Buffer-based APIs remain the same since they were already modern:

#### Both v0.4.x and v0.5.0
```crystal
# No changes needed
palette = PrismatIQ.get_palette_from_buffer(pixels, width, height, options)
entries, total = PrismatIQ.get_palette_with_stats(pixels, width, height, options)
hex_colors = PrismatIQ.get_palette_color_thief(pixels, width, height, options)
```

## Step-by-Step Migration

### Step 1: Update Palette Extraction Calls

Replace all `get_palette` calls with appropriate v2 equivalents:

```ruby
# Find and replace patterns:
s/PrismatIQ\.get_palette\(/PrismatIQ.get_palette_v2!(/g          # For simple cases
s/PrismatIQ\.get_palette\(/result = PrismatIQ.get_palette_v2(/g   # For Result handling
```

### Step 2: Update ICO File Handling

Replace ICO method calls:

```ruby
# Find and replace:
s/PrismatIQ\.get_palette_from_ico\(/PrismatIQ.get_palette_from_ico_v2!(/g
```

### Step 3: Instantiate Utility Classes

Replace module-level accessibility and theme calls:

```crystal
# Add instance creation at the beginning of your methods/classes
calculator = PrismatIQ::AccessibilityCalculator.new
detector = PrismatIQ::ThemeDetector.new

# Then replace all module calls with instance calls
# s/PrismatIQ::Accessibility\./calculator./g
# s/PrismatIQ::Theme\./detector./g
```

### Step 4: Handle Errors Appropriately

Update error handling patterns:

- **Remove sentinel value checks** (`== [RGB.new(0,0,0)]`)
- **Add proper Result handling** or use exception-based APIs
- **Update error messages** to use structured `Error` fields

### Step 5: Update Tests

Tests should be updated to use v2 APIs:

```crystal
# Before
colors = PrismatIQ.get_palette(path, options)
expect(colors).not_to eq([RGB.new(0,0,0)])

# After  
result = PrismatIQ.get_palette_v2(path, options)
expect(result.ok?).to be_true
colors = result.value
```

## Benefits of v0.5.0

### Improved Error Handling
- **Structured errors** with specific error types and context
- **Explicit error handling** forces consideration of failure cases
- **Better debugging** with detailed error information

### Better Architecture
- **Instance-based design** eliminates shared mutable state
- **Thread safety** by default with no global caches to clear
- **Clear separation of concerns** between different functionality areas

### Modern Crystal Patterns
- **Result types** for functional error handling
- **Options struct** as single source of truth for configuration
- **Exception variants** for simpler error handling when needed

### Performance Maintained
- **All v0.4.x optimizations preserved**:
  - Memory optimization (25-40% reduction)
  - Thread safety improvements
  - Security fixes (path traversal, shell injection)
  - Fiber-based parallelism

## Common Migration Issues

### Issue 1: "undefined method 'get_palette'"
**Solution**: Replace with `get_palette_v2` or `get_palette_v2!`

### Issue 2: "undefined constant PrismatIQ::Accessibility"
**Solution**: Create `AccessibilityCalculator.new` instance and use instance methods

### Issue 3: Sentinel error checking fails
**Solution**: Remove `[RGB.new(0,0,0)]` checks and use proper Result handling

### Issue 4: Tests fail with old API calls
**Solution**: Update all test code to use v2 APIs as shown in examples above

## Example: Complete Migration

#### Before (v0.4.x)
```crystal
def process_image(path)
  options = PrismatIQ::Options.new(color_count: 5)
  colors = PrismatIQ.get_palette(path, options)
  
  if colors == [RGB.new(0,0,0)]
    return {:error => "Failed to process image"}
  end
  
  # Check accessibility
  bg = colors.first
  fg = PrismatIQ::Accessibility.recommend_text_color(bg)
  
  # Detect theme
  theme = PrismatIQ::Theme.detect_theme(bg)
  
  {:success => {:colors => colors, :foreground => fg, :theme => theme}}
end
```

#### After (v0.5.0)
```crystal
def process_image(path)
  options = PrismatIQ::Options.new(color_count: 5)
  calculator = PrismatIQ::AccessibilityCalculator.new
  detector = PrismatIQ::ThemeDetector.new
  
  result = PrismatIQ.get_palette_v2(path, options)
  return {:error => "Failed to process image"} unless result.ok?
  
  colors = result.value
  bg = colors.first
  fg = calculator.recommend_text_color(bg)
  theme = detector.detect_theme(bg)
  
  {:success => {:colors => colors, :foreground => fg, :theme => theme}}
end
```

This migration results in more robust, maintainable, and thread-safe code while maintaining all the performance benefits of v0.4.x.