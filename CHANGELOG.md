# Changelog

All notable changes to this project will be documented in this file.

## [0.5.5.0] - 2026-03-18

### Changed

- **Code Quality & Readability**: Significant improvements to code maintainability and readability
  - Replaced non-idiomatic Crystal patterns with proper idiomatic alternatives
  - Renamed internal/private functions with overly long names (4+ words) to use maximum 2-3 words while maintaining clarity
  - Improved overall code structure and consistency across the codebase
  - Added explanatory comments for `Time.monotonic` usage due to Crystal 1.18.2 constraint

### Internal Improvements

- **Function Naming**: Shortened internal function names for better readability while preserving all functionality
  - ThemeExtractor: `extract_bg_from_ico` → `extract_ico_bg`, `extract_colors_from_pixels` → `extract_pixel_colors`
  - PaletteExtractor: `build_histo_from_buffer` → `build_buffer_histo`
  - ICO Parser: `find_png_at_entry` → `find_png_entry`, `find_best_bmp_entry` → `find_best_bmp`
  - MMCQ Algorithm: `log_debug_popped_box` → `log_popped_box`, `log_debug_split_result` → `log_split_result`
  - BMP Parser: `mask_to_shift_and_bits` → `mask_to_shift_bits`, `parse_header_fields_only` → `parse_header_fields`

- **Public API Stability**: All public APIs remain unchanged and fully backward compatible

## [0.5.4.0] - 2026-03-16

### Fixed

- **Critical deadlock in palette extraction**: Fixed indefinite blocking when processing small images with high thread counts
  - Track actual spawned fiber count instead of assuming thread_count
  - Add proper exception handling in worker fibers to prevent crashes
  - Ensure all spawned fibers send messages to prevent deadlock

- **SVG theme extraction**: Added SVG support to theme extraction
  - Handle SVG files in extract_from_image and extract_from_image_buffer
  - Use SVGColorExtractor for SVG files instead of CrImage (which doesn't support SVG)

### Changed

- **ThreadSafeCache documentation**: Added performance note about mutex blocking during computation

## [0.5.3.1] - 2026-03-16

### Fixed

- **Crystal 1.18.2 Compatibility**: Changed from `Time.instant` to `Time.monotonic` for rate limiting
  - Fixes compatibility with Crystal 1.18.2 which is specified in shard.yml
  - Uses `Time::Span` instead of `Time::Instant` for timestamp tracking

## [0.5.3] - 2026-03-16

### Added

- **SVG Color Extraction**: Pure Crystal SVG color extractor that parses SVG XML and extracts colors directly without rasterization
  - Supports hex, RGB, RGBA, HSL, HSLA, and 140+ named CSS colors
  - Extracts from all color attributes (`fill`, `stroke`, `stop-color`, `flood-color`, `lighting-color`, `color`)
  - No external dependencies required - pure Crystal implementation
  - Returns `Result(Array(RGB), Error)` with explicit error handling
  - Comprehensive test coverage (29 test cases)

### Security

- **Error Context Sanitization**: Prevent path information leakage in error messages
  - Sanitized error contexts to avoid leaking file paths or sensitive information

### Fixed

- **Favicon handling**: Fixed various issues with bad/invalid favicon processing
- **Code quality**: Reduced cyclomatic complexity in ThemeExtractor and Validation modules
- **Maintainability**: Extracted common ICO/image extraction logic into shared methods
- **Lint compliance**: Fixed all ameba linting issues across the codebase
- **Rate limiting**: Implemented exponential backoff for better resource management
- **Documentation**: Added comprehensive docs to public APIs (ThemeExtractor, Config, RateLimiter)

## [0.5.2] - 2026-03-15

### Security

- **SSRF Protection**: Added comprehensive Server-Side Request Forgery protection for ThemeExtractor HTTP client
  - Blocks requests to private/reserved IP ranges (10.x, 172.16-31.x, 192.168.x, 127.x, 169.254.x, 0.x, ::1, fc00::/7, fe80::/10)
  - URL scheme validation - only `http://` and `https://` allowed
  - DNS resolution and IP validation before connection
  - Configurable allowlist for trusted internal hosts
  - Controlled via `Config.ssrf_protection` and `Config.ssrf_allowlist`

- **Path Validation**: Enhanced path validation security
  - Blocks URL-encoded path traversal (`%2e%2e`, `%252e%252e`, `..%2f`)
  - Blocks null byte injection (`\0`)
  - Blocks encoded tilde (`%7e`)

### Fixed

- **Silent Exception Handling**: Eliminated empty rescue blocks that silently swallowed exceptions
  - All rescued exceptions now logged when `PRISMATIQ_DEBUG=true`
  - Log messages include method context and exception type
  - Improved debugging visibility for production issues

- **Global State**: Replaced mutable class variable with thread-safe singleton pattern
  - `ThemeExtractor` now uses mutex-protected lazy initialization
  - Eliminates potential race conditions in concurrent access

- **Validation Consolidation**: Removed duplicate validation logic
  - `Validation.validate_options` now delegates to `Options.validate!`
  - Single source of truth for option validation

- **File Size Limits**: Unified file size limits across components
  - `TempfileHelper::MAX_DATA_SIZE` aligned with `Validation::MAX_FILE_SIZE` (100MB)

### Added

- New `IPValidator` utility module for IP address validation
- New `SSRFError` exception class with URL, IP, and reason context
- New `Error.ssrf_blocked` factory method
- New `ErrorType::SSRFBlocked` enum value
- Comprehensive test coverage for security features (13 new test cases)

## [0.5.1] - Unreleased

### Added

#### Theme Extraction API
- **Unified theme extraction**: `extract_theme(source, options)` supports files, URLs, and buffers
- **Theme-aware results**: Returns background color with compliant light/dark text colors
- **Accessibility auto-correction**: `fix_theme(theme_json, legacy_bg, legacy_text)` ensures WCAG 4.5 compliance
- **Built-in HTTP support**: Fetches images from URLs using Crystal's built-in HTTP client
- **Thread-safe caching**: 7-day TTL caching with proper expiration
- **Concise API surface**: Clean, generic method names suitable for any project
- **Drop-in compatibility**: JSON format matches quickheadlines expectations

## [0.5.0] - 2026-03-14

### Breaking Changes

#### Clean API Break
- **Complete removal of all deprecated v1 APIs** that used sentinel error values `[RGB.new(0,0,0)]`
- **Removal of module-level `Accessibility` and `Theme` methods** - users must now create `AccessibilityCalculator` and `ThemeDetector` instances
- **All APIs now return explicit error handling** using `Result(Array(RGB), Error)` types or raise exceptions
- **Simplified method signatures** - removed redundant overloads and parameter combinations

#### Removed Methods
- All v1 `get_palette` methods returning `Array(RGB)` with sentinel errors
- All v1 `get_palette_or_error` methods returning `Result(Array(RGB), String)`
- All deprecated positional parameter APIs (e.g., `get_palette(path, color_count, quality, threads)`)
- Module-level `PrismatIQ::Accessibility` and `PrismatIQ::Theme` methods
- `PaletteResult` struct (redundant with `Result` type)

#### Renamed Methods (Clean Names)
- `get_palette_v2` → `get_palette` (now returns `Result(Array(RGB), Error)`)
- `get_palette_v2!` → `get_palette!` (now raises exceptions on error)
- `get_palette_from_ico_v2` → `get_palette_from_ico` (now returns `Result(Array(RGB), Error)`)

### Added

#### Modern Result-Based API
- **Primary API**: `get_palette` returns `Result(Array(RGB), Error)` with structured error information
- **Exception-based API**: `get_palette!` raises exceptions on errors for simpler error handling  
- **Comprehensive Error struct** with `type`, `message`, and `context` fields for precise error handling
- **All utility methods updated** to use consistent Result-based error handling

#### Instance-Based Utility Classes
- **`AccessibilityCalculator`** - Instance-based accessibility calculations with isolated caching
- **`ThemeDetector`** - Instance-based theme detection with isolated caching  
- **Thread-safe by design** - no shared mutable state between instances
- **Configurable instances** - each can have different configuration

### Changed

#### API Design Philosophy
- **Explicit over implicit** - All errors are explicitly handled through Result types
- **Instance-based over module-based** - Better encapsulation and thread safety
- **Modern Crystal patterns** - Leverages Crystal's type system and functional programming features
- **Single source of truth** - `Options` struct remains the configuration standard

#### Performance and Security
- **Maintains all v0.4.x improvements**: Memory optimization, thread safety, security fixes
- **Continues using Options struct** as the single source of truth for configuration
- **Preserves all existing performance optimizations** and security measures
- **Optimized concurrency** - lock-free histogram pool eliminates mutex bottlenecks

### Fixed
- **Race conditions** in utility modules (now fully instance-based)
- **Memory allocation overhead** in histogram processing (lock-free design)
- **Ambiguous error handling** (replaced with explicit Result types)

### Migration Guide for v0.5.0

#### Palette Extraction
```crystal
# Before (v0.4.x) - Ambiguous sentinel errors
colors = PrismatIQ.get_palette("image.png", options)
if colors == [RGB.new(0,0,0)]
  puts "Error occurred"
end

# After (v0.5.0) - Explicit Result-based
result = PrismatIQ.get_palette("image.png", options)
if result.ok?
  colors = result.value
else
  puts "Error: #{result.error.message} (#{result.error.type})"
end

# After (v0.5.0) - Exception-based (simpler cases)  
colors = PrismatIQ.get_palette!("image.png", options) # Raises on error
```

#### ICO File Support
```crystal
# Before (v0.4.x) - Sentinel error checking
colors = PrismatIQ.get_palette_from_ico("icon.ico", options)
if colors.size == 1 && colors[0].r == 0
  puts "ICO error"
end

# After (v0.5.0) - Explicit Result handling
result = PrismatIQ.get_palette_from_ico("icon.ico", options)
case result
when .ok?
  colors = result.value
when .err?
  puts "ICO error: #{result.error.message} (#{result.error.type})"
end
```

#### Accessibility Calculations
```crystal
# Before (v0.4.x) - Module-level methods
lum = PrismatIQ::Accessibility.relative_luminance(color)
level = PrismatIQ::Accessibility.wcag_level(fg, bg)

# After (v0.5.0) - Instance-based
calculator = PrismatIQ::AccessibilityCalculator.new
lum = calculator.relative_luminance(color)
level = calculator.wcag_level(fg, bg)
```

#### Theme Detection  
```crystal
# Before (v0.4.x) - Module-level methods
theme = PrismatIQ::Theme.detect_theme(background)
palette = PrismatIQ::Theme.suggest_text_palette(background)

# After (v0.5.0) - Instance-based
detector = PrismatIQ::ThemeDetector.new
theme = detector.detect_theme(background)
palette = detector.suggest_text_palette(background)
```

#### Buffer-based Extraction (unchanged)
```crystal
# This API remains the same since it was already modern
options = PrismatIQ::Options.new(color_count: 5, quality: 10)
palette = PrismatIQ.get_palette(pixels, width, height, options)
```

### Examples Updated
- All examples and documentation updated to use v0.5.0 APIs
- ColorThief adapter example uses v0.5.0 APIs for ICO files  
- Comprehensive test coverage for new APIs (220+ tests passing)
- Full ameba linting compliance (zero warnings/errors)

## v0.4.1 - 2026-03-04

### Breaking Changes
- **Removed deprecated API methods**: The following deprecated methods have been removed:
  - `get_palette(path, color_count, quality)` - use `get_palette(path, Options.new(color_count: N, quality: Q))` instead
  - `get_palette(io, color_count, quality)` - use `get_palette(io, Options.new(color_count: N, quality: Q))` instead
  - `get_palette(img, color_count, quality, threads)` - use `get_palette(img, Options.new(color_count: N, quality: Q, threads: T))` instead
  - `get_palette_with_stats_from_buffer` - use `get_palette_with_stats` instead
  - `get_palette_result_from_buffer` - use `get_palette_result` instead
  - `get_palette_color_thief_from_buffer` - use `get_palette_color_thief` instead

[... rest of the file remains the same ...]
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