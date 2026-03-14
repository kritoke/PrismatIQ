## Why

The code review identified several areas for improvement in the PrismatIQ codebase: inconsistent error handling patterns (mixed sentinel values and Result types), potential resource leaks in tempfile cleanup, optimization opportunities in histogram building, incomplete API documentation, and type safety gaps. These issues reduce code quality, maintainability, and could cause runtime issues in edge cases.

## What Changes

1. **Standardize error handling** - Migrate all public API methods to use consistent `Result(Array(RGB), Error)` return types, deprecating legacy sentinel value returns
2. **Enhance tempfile cleanup** - Implement atomic cleanup with stronger guarantees and timeout-based orphaned file handling
3. **Optimize histogram building** - Add bounds checking optimization and profile memory allocation patterns in pixel processing loops
4. **Complete API documentation** - Add usage examples and edge case documentation to all public methods
5. **Improve type safety** - Use explicit `Nil` returns or `Result` types consistently, add more specific type annotations

## Capabilities

### New Capabilities
- `error-handling-standardization`: Standardize all API methods to use consistent Result-based error handling
- `tempfile-robustness`: Improve temporary file cleanup reliability with atomic operations
- `histogram-optimization`: Optimize pixel processing loops for better performance

### Modified Capabilities
- (none - these are refactoring/improvement tasks, not spec-level behavior changes)

## Impact

- **Code affected**: `src/prismatiq.cr`, `src/prismatiq/tempfile_helper.cr`, `src/prismatiq/core/palette_extractor.cr`
- **APIs affected**: All public API methods in PrismatIQ module
- **Breaking changes**: Deprecated legacy methods returning sentinel values will be removed in v0.7.0
