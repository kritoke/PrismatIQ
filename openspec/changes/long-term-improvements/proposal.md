## Why

Following the successful v0.5.0 refactoring, several opportunities for further improvement have been identified that would enhance code maintainability, reduce technical debt, and prepare for future features. These changes address file size targets not fully met in v0.5.0, API consistency issues, and architectural improvements that will make the codebase more modular and easier to extend.

## What Changes

- **File Size Reduction**: Extract MMCQ algorithm logic from `prismatiq.cr` (1180 lines) into a dedicated `mmcq.cr` file to meet the 800-line target
- **ICO Module Splitting**: Extract PNGExtractor from `ico.cr` (1030 lines) into its own file to improve modularity and meet the 800-line target  
- **API Consolidation**: **BREAKING** - Consolidate dual result types (`PaletteResult` and `Result(T, E)`) into a single, unified error handling approach
- **Enhanced Error Handling**: Extend the chosen result type to carry metadata (like `total_pixels`) while maintaining explicit error semantics
- **Code Organization**: Further modularize the main `prismatiq.cr` file by extracting related functionality into focused modules

## Capabilities

### New Capabilities
- `mmcq-algorithm-module`: Dedicated MMCQ (Modified Median Cut Quantization) algorithm implementation in separate file
- `png-extractor-module`: Standalone PNG extraction module for ICO file handling
- `unified-result-type`: Single, consistent error handling approach with metadata support

### Modified Capabilities
- `palette-extraction-api`: API simplified to use single result type instead of dual approaches
- `ico-file-support`: Modularized with separate PNG and BMP components
- `prismatiq-impl`: Core implementation split into smaller, focused files

## Impact

- **Affected Files**: 
  - `src/prismatiq.cr` (significant reduction in size)
  - `src/prismatiq/ico.cr` (extraction of PNGExtractor)
  - `src/prismatiq/mmcq.cr` (new file for algorithm)
  - `src/prismatiq/png_extractor.cr` (new file for PNG handling)
- **API Changes**: Breaking change to consolidate `PaletteResult` and `Result(T, E)` into unified approach
- **Dependencies**: No new external dependencies; internal reorganization only
- **Testing**: Test suite updated to match new file structure and unified API
- **Documentation**: README and CHANGELOG updated for v0.6.0 breaking changes