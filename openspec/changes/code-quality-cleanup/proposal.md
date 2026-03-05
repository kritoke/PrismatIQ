## Why

The codebase has 45 remaining Ameba linting issues that should be addressed to improve code quality, maintainability, and follow Crystal best practices. These are primarily cyclomatic complexity issues and some remaining stylistic issues that don't affect functionality but do affect code readability and long-term maintainability.

## What Changes

- **Reduce Cyclomatic Complexity** in 9 methods across 5 files to meet the 12-point threshold
- **Fix Remaining Stylistic Issues**: Remove redundant nil checks, redundant begin blocks, and unused variable assignments
- **Improve Code Readability**: Better code structure makes the codebase easier to understand and maintain
- **No Breaking Changes**: All changes are internal refactoring with no API changes

## Capabilities

### New Capabilities
- None - this is a code quality improvement with no new functionality

### Modified Capabilities
- `prismatiq-impl`: Internal code quality improvements

## Impact

- **Affected Files**:
  - `src/cpu_cores.cr` - Reduce complexity in `cores` and `l2_cache_bytes` methods
  - `src/prismatiq.cr` - Reduce complexity in `quantize` method
  - `src/prismatiq/tempfile_helper.cr` - Reduce complexity in `create_and_write` method
  - `src/prismatiq/bmp_parser.cr` - Reduce complexity in `parse_header_fields_only` and `parse_header` methods
  - `src/prismatiq/ico.cr` - Reduce complexity in `extract_from_ico` and `best_bmp_entry` methods
  - `src/prismatiq/color_extractor.cr` - Reduce complexity in `extract_from_buffer` method
- **No API Changes**: All changes are internal refactoring
- **No Dependencies**: No new external dependencies