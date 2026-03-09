# Changelog

All notable changes to this project will be documented in this file.

## [0.6.0] - 2026-03-09

### Added

#### New v2 Result-Based API
- `get_palette_v2(path, options)` - Returns `Result(Array(RGB), Error)` for explicit error handling
- `get_palette_v2!(path, options)` - Raises exceptions on errors
- `get_palette_v2(io, options)` - Extract palette from IO with Result type
- `get_palette_v2(pixels, width, height, options)` - Extract from raw pixels with Result type
- Comprehensive v2 API documentation in `docs/V2_API_GUIDE.md`

#### Structured Error Handling
- `Error` struct with `type`, `message`, and `context` fields
- `ErrorType` enum with 6 error types:
  - `FileNotFound` - File doesn't exist
  - `InvalidImagePath` - Path validation failed
  - `UnsupportedFormat` - Image format not supported
  - `CorruptedImage` - Image data is corrupt
  - `InvalidOptions` - Parameter validation failed
  - `ProcessingFailed` - General processing error
- Factory methods for each error type

#### Thread-Safe Classes
- `AccessibilityCalculator` - Instance-based accessibility calculations with isolated caching
- `ThemeDetector` - Instance-based theme detection with isolated caching

#### Memory Optimization
- `HistogramPool` - Object pool for histogram reuse (25-40% memory reduction)
- `AdaptiveChunkSizer` - Optimal processing based on image size

#### Input Validation
- `Utils::Validation.validate_file_path(path)` - Comprehensive path validation
- `Utils::Validation.validate_options(options)` - Parameter validation
- `Utils::Validation.validate_io(io)` - IO stream validation

#### Code Organization
- Extracted 10 focused modules from monolithic file
- Clear module boundaries and responsibilities
- Reduced main file by 47% (991 → 526 lines)

#### Fiber-Based Parallelism
- Migrated from `Thread.new` to `spawn` for parallel processing
- Channel-based histogram result collection
- Better integration with Crystal's scheduler

#### Testing
- Added 40 comprehensive tests (total: 262 tests, 100% pass rate)
- Thread safety tests
- Concurrent access tests
- Memory pool tests

### Changed

#### Performance Improvements
- Memory usage reduced by 25-40% on typical workloads
- Small images (<100K): ~90% reduction
- Medium images (1M): ~50% reduction
- Large images (10M): ~25% reduction
- Adaptive processing eliminates overhead for small images

#### Code Quality
- Main file reduced by 47% (991 → 526 lines)
- Removed 465 lines of duplicate code
- Improved code navigation

### Security

- **CRITICAL**: Eliminated shell command injection vulnerability in CPU detection
- **HIGH**: Added path traversal prevention
- **MEDIUM**: Added file size limits (100MB max)
- **LOW**: Sanitized error messages to not expose full paths

### Fixed

- Race conditions in accessibility and theme modules (now instance-based)
- Memory leaks from histogram allocation (now pooled)
- Inefficient processing of small images (now single-threaded)
- Inconsistent error handling (now unified with Result types)

### Deprecated

The following are deprecated and will be removed in v0.8.0:

- `get_palette(path, color_count, quality, threads)` - Use `get_palette_v2(path, options)`
- `PaletteResult` struct - Use `Result(Array(RGB), Error)`
- Sentinel error value `[RGB.new(0,0,0)]` - Check for `Result::Err` instead
- Module-level `Accessibility` methods - Use `AccessibilityCalculator` instance
- Module-level `Theme` methods - Use `ThemeDetector` instance

### Migration Guide for v0.6.0

See `docs/V2_API_GUIDE.md` for detailed migration instructions.

**Quick migration:**

```crystal
# Before (0.5.x)
colors = PrismatIQ.get_palette("image.png", options)
if colors == [RGB.new(0,0,0)]
  puts "Error"
end

# After (0.6.0)
result = PrismatIQ.get_palette_v2("image.png", options)
if result.ok?
  colors = result.value
else
  puts "Error: #{result.error.message}"
end
```

## v0.4.1 - 2026-03-04

### Breaking Changes
- **Removed deprecated API methods**: The following deprecated methods have been removed:
  - `get_palette(path, color_count, quality)` - use `get_palette(path, Options.new(color_count: N, quality: Q))` instead
  - `get_palette(io, color_count, quality)` - use `get_palette(io, Options.new(color_count: N, quality: Q))` instead
  - `get_palette(img, color_count, quality, threads)` - use `get_palette(img, Options.new(color_count: N, quality: Q, threads: T))` instead
  - `get_palette_with_stats_from_buffer` - use `get_palette_with_stats` instead
  - `get_palette_result_from_buffer` - use `get_palette_result` instead
  - `get_palette_color_thief_from_buffer` - use `get_palette_color_thief` instead

### Migration Guide for v0.5.0

If you were using the deprecated keyword-argument API, update your code:

**Before (deprecated - removed in v0.5.0):**
```crystal
palette = PrismatIQ.get_palette(path, 5, 10)
palette = PrismatIQ.get_palette(img, 5, 10, 4)
entries, total = PrismatIQ.get_palette_with_stats_from_buffer(pixels, w, h, 5, 10, 1)
result = PrismatIQ.get_palette_result_from_buffer(pixels, w, h, 5, 10, 1)
hex_colors = PrismatIQ.get_palette_color_thief_from_buffer(pixels, w, h, 5, 10)
```

**After (v0.5.0+):**
```crystal
options = PrismatIQ::Options.new(color_count: 5, quality: 10)
palette = PrismatIQ.get_palette(path, options)
palette = PrismatIQ.get_palette(img, PrismatIQ::Options.new(color_count: 5, quality: 10, threads: 4))
entries, total = PrismatIQ.get_palette_with_stats(pixels, w, h, options)
result = PrismatIQ.get_palette_result(pixels, w, h, options)
hex_colors = PrismatIQ.get_palette_color_thief(pixels, w, h, options)
```

## v0.4.0 - 2026-02-26

### Added
- `Result(T, E)` type for explicit error handling (inspired by Rust's Result). Provides `ok?`, `err?`, `value`, `error`, `value_or`, `map`, `flat_map`, `map_error`.
- `get_palette_or_error` methods returning `Result(Array(RGB), String)`.
- `Config` struct for runtime settings (debug, threads, merge_chunk) - enables config injection without ENV vars.
- `process_pixel_range` helper function for pixel processing.
- Tests for `Result` type and `Config`.

### Changed
- Made `RGB`, `Color`, `VBox` immutable (changed `property` to `getter`).
- Refactored `VBox#recalc_count` to return new VBox instead of mutating.
- Replaced imperative loops with functional transforms where appropriate (`compact_map`, `Slice.new`).
- Extracted thread count logic into `Config#thread_count_for`.

### Improved
- Functions are now more testable with explicit Config parameter.
- Cleaner code flow in histogram building.
- Backward compatible - existing APIs work unchanged.

### Migration Guide for v0.4.0

This release includes breaking changes from the refactor-dry-functional change. While most APIs remain backward compatible through deprecation warnings, here are the key changes you should be aware of:

#### 1. Struct Immutability (RGB, Color, VBox)

The `RGB`, `Color`, and `VBox` structs are now immutable. If you were mutating these objects directly, you need to update your code:

**Before (v0.3.x and earlier):**
```crystal
rgb = RGB.new(255, 0, 0)
rgb.r = 128  # This worked before
```

**After (v0.4.0+):**
```crystal
rgb = RGB.new(255, 0, 0)
# rgb.r = 128  # This will cause a compile error
# Use a new instance instead:
rgb = RGB.new(128, 0, 0)
```

#### 2. VBox#recalc_count Returns New Instance

The `VBox#recalc_count` method now returns a new VBox instead of mutating the existing one:

**Before:**
```crystal
vbox = VBox.new(...)
vbox.recalc_count  # Mutated vbox in place
```

**After:**
```crystal
vbox = VBox.new(...)
vbox = vbox.recalc_count  # Assign the returned new VBox
```

#### 3. API Consolidation to Options Struct

The API now uses `Options` as the single source of truth for extraction parameters. While deprecated methods still work, prefer the new pattern:

**Before (deprecated but still works):**
```crystal
palette = PrismatIQ.get_palette(path, 5, 10)
palette = PrismatIQ.get_palette(img, 5, 10, 4)
```

**After (recommended):**
```crystal
options = PrismatIQ::Options.new(color_count: 5, quality: 10)
palette = PrismatIQ.get_palette(path, options)

# Or with threads:
options = PrismatIQ::Options.new(color_count: 5, quality: 10, threads: 4)
palette = PrismatIQ.get_palette(img, options)
```

#### 4. Error Handling with Result Type

New `get_palette_or_error` methods provide explicit error handling:

**Recommended pattern:**
```crystal
result = PrismatIQ.get_palette_or_error(path, options)
if result.ok?
  palette = result.value
else
  puts "Error: #{result.error}"
end
```

**Or use `value_or` for defaults:**
```crystal
palette = PrismatIQ.get_palette_or_error(path, options).value_or([RGB.new(0, 0, 0)])
```

#### 5. Config for Runtime Settings

Use `Config` to control debugging and threading without environment variables:

```crystal
config = PrismatIQ::Config.new(debug: true, threads: 4)
palette = PrismatIQ.get_palette(pixels, width, height, options, config)
```

#### 6. Deprecated Methods

The following methods are deprecated and will be removed in a future version:

- `get_palette(path, color_count, quality)` - Use `get_palette(path, Options.new(...))`
- `get_palette(io, color_count, quality)` - Use `get_palette(io, Options.new(...))`
- `get_palette(img, color_count, quality, threads)` - Use `get_palette(img, Options.new(...))`
- `get_palette_from_buffer(pixels, width, height, color_count, quality, threads)` - Use the Options variant
- `get_palette_result_from_buffer(...)` - Use `get_palette_result(...)`
- `get_palette_with_stats_from_buffer(...)` - Use `get_palette_with_stats(...)`
- `get_palette_color_thief_from_buffer(...)` - Use `get_palette_color_thief(...)`

#### 7. Constants Organization

Constants are now organized under `PrismatIQ::Constants`:

```crystal
PrismatIQ::Constants::ALPHA_THRESHOLD_DEFAULT
PrismatIQ::Constants::HISTOGRAM_SIZE
PrismatIQ::Constants::WCAG::CONTRAST_RATIO_AA
PrismatIQ::Constants::WCAG::CONTRAST_RATIO_AAA
PrismatIQ::Constants::YIQ::Y_FROM_R
# etc.
```

---

## v0.2.0 - 2026-02-16

- Add public API: `get_palette_with_stats_from_buffer` returning counts and percentages.
- Add compatibility wrapper `get_palette_color_thief_from_buffer` returning hex strings.
- Add example CLI `examples/color_thief_adapter.cr` and `examples/README.md` demonstrating ColorThief-compatible output.
- Add deterministic priority tie-breaking in MMCQ to ensure stable palettes across thread counts.
- Add tests exercising the new APIs and verifying determinism.
- Add GitHub Actions CI workflow that runs specs and executes the example against a sample image.

## v0.1.0 - Initial release

- Initial public release of PrismatIQ (v0.1.0). Includes:
  - Core MMCQ implementation on YIQ color space with 5-bit quantization per axis.
  - Buffer-based extraction APIs and ColorThief-compatible helpers.
  - Multithreaded histogram building with adaptive chunked merging.
  - Tests, example adapter, and CI workflow.
