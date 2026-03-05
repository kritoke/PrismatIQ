## Why

The newly implemented WCAG Contrast Functions and ICO support contain critical bugs and design issues that prevent production use. These include incorrect WCAG compliance level logic, thread-safety vulnerabilities in caching, dead code in ICO parsing, and poor error handling patterns. This change addresses these issues to ensure the library is robust, correct, and performant.

## What Changes

- **Fix WCAG level logic**: Correct large text compliance to return `AA_Large` instead of `AA` for 3:1-4.5:1 ratios
- **Add thread-safety**: Implement mutex protection for global caches to prevent race conditions
- **Enable ICO bitfield support**: Allow BI_BITFIELDS (compression=3) through compression validation
- **Add bounds checking**: Implement explicit bounds validation for slice reads to prevent IndexError
- **Improve error handling**: Add `get_palette_from_ico_or_error` returning `Result(Array(RGB), String)` 
- **Update documentation**: Clarify sentinel return behavior and add proper error handling examples
- **Add missing tests**: Concurrency, edge cases, and failure mode coverage

## Capabilities

### New Capabilities
- `wcag-compliance`: WCAG 2.0/2.1 accessibility compliance checking with proper large text support
- `theme-detection`: Thread-safe theme detection with caching
- `ico-parsing`: Robust ICO file parsing with proper error handling and bitfield support

### Modified Capabilities
- `color-palette-extraction`: Enhanced error handling with Result types and better documentation

## Impact

- **Code**: Modifications to `src/prismatiq/accessibility.cr`, `src/prismatiq/theme.cr`, `src/prismatiq/ico.cr`
- **APIs**: New `get_palette_from_ico_or_error` function, updated cache clearing methods
- **Dependencies**: Added `concurrent` import for Mutex support
- **Documentation**: Updated README.md with proper error handling examples
- **Testing**: New test coverage for concurrency, edge cases, and failure modes