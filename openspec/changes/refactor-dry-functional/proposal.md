## Why

The PrismatIQ codebase currently suffers from significant code duplication, inconsistent error handling patterns, and an overly complex API surface. Multiple approaches to similar problems (error handling, caching, configuration validation) create maintenance burden and cognitive overhead for developers. This refactoring will simplify the codebase by standardizing patterns, eliminating redundancy, and creating a more functional, DRY (Don't Repeat Yourself) architecture while maintaining backward compatibility where possible.

## What Changes

- **Standardize Error Handling**: Replace sentinel values `[RGB.new(0, 0, 0)]`, `PaletteResult` struct, and mixed exception-based approaches with consistent `Result(Array(RGB), String)` return types across all public APIs
- **Consolidate Configuration**: Remove redundant `validate_params` method and make `Options` struct the single source of truth for extraction parameters
- **Create Generic Thread-Safe Cache**: Replace duplicated caching patterns in `Accessibility` and `Theme` modules with a reusable `ThreadSafeCache(K, V)` class
- **Extract YIQ Conversion Logic**: Centralize color space conversion logic into a dedicated `YIQConverter` module to eliminate duplication across `quantize_yiq_from_rgb`, `Color.from_rgb`, and `sort_by_popularity`
- **Simplify ICO Module**: Break down the 662-line `ico.cr` file into smaller, focused components (`BMPParser`, `ICOEntry`, etc.) with cleaner separation of concerns
- **Refactor Multi-threading Infrastructure**: Extract generic parallel processing logic into a reusable `ParallelProcessor` class
- **Consolidate Constants**: Move scattered constants (WCAG ratios, luminance thresholds) into the main `PrismatIQ::Constants` namespace
- **Rationalize API Surface**: Reduce public API from multiple similar method signatures to a minimal core set using `Options` parameter exclusively
- **BREAKING**: Remove deprecated method overloads and `PaletteResult` struct in favor of standardized `Result` type

## Capabilities

### New Capabilities
- `error-handling-standardization`: Standardized error handling using Result types across all public APIs
- `generic-thread-safe-cache`: Reusable ThreadSafeCache class for eliminating duplicated caching patterns  
- `yiq-conversion-centralization`: Centralized YIQ color space conversion logic in dedicated module
- `parallel-processing-infrastructure`: Generic ParallelProcessor class for reusable multi-threading patterns

### Modified Capabilities
- `palette-extraction-api`: Public API simplified to use Options struct exclusively with standardized Result return types
- `accessibility-module`: Refactored to use generic ThreadSafeCache instead of manual mutex management
- `theme-module`: Refactored to use generic ThreadSafeCache instead of manual mutex management
- `ico-file-support`: Restructured into modular components with cleaner separation of concerns

## Impact

- **Affected Files**: 
  - `src/prismatiq.cr` (core module - major changes)
  - `src/prismatiq/accessibility.cr` (caching refactoring)
  - `src/prismatiq/theme.cr` (caching refactoring) 
  - `src/prismatiq/ico.cr` (major restructuring)
  - `src/cpu_cores.cr` (minor cleanup)
  - `src/prismatiq/tempfile_helper.cr` (minor cleanup)
  - All spec files (updates for new API patterns)
- **API Changes**: Breaking changes to public method signatures; migration path provided through deprecation warnings initially
- **Dependencies**: No new external dependencies; internal reorganization only
- **Testing**: All existing functionality preserved; test suite updated to match new API patterns