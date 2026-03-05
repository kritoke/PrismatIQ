# Changelog

All notable changes to this project will be documented in this file.

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
