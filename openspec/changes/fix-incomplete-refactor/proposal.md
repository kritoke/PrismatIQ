# Fix Incomplete Refactor and Thread Safety Issues

## Problem Statement

The codebase has critical issues that prevent it from compiling and running correctly:

1. **Missing Implementation**: The `PaletteConvenience` class is referenced throughout the codebase but the implementation file `src/prismatiq/core/palette_convenience.cr` is missing, making the entire library unusable.

2. **Thread Safety Violations**: Despite documentation claiming "fully thread-safe", the implementation has serious race conditions:
   - `HistogramPool` lacks proper synchronization for concurrent access
   - Histogram modification during parallel processing is not thread-safe
   - No protection for shared mutable state

3. **Error Handling Inconsistencies**: Mixed error handling patterns (exceptions, Result types, silent failures with sentinel values) make the API unpredictable and hard to use correctly.

4. **Algorithmic Bugs**: 
   - YIQ quantization has incorrect scaling math
   - VBox.split has performance issues (O(n) per split)
   - Unnecessary runtime type checks in performance-critical paths

5. **API Confusion**: Multiple conflicting APIs exist simultaneously, making it unclear which to use.

## Root Cause Analysis

A refactor was attempted that:
- Moved method signatures to the main `PrismatIQ` module
- Renamed methods (e.g., `get_palette_with_stats_from_buffer` → `get_palette_with_stats`)
- Planned to create a `PaletteConvenience` class to implement the convenience features

However, the refactor was never completed:
- The `PaletteConvenience` class was never created
- Tests reference the new API but cannot run due to missing implementation
- The backup file shows the same incomplete state

## Proposed Solution

### Phase 1: Complete the Incomplete Refactor
- Create `src/prismatiq/core/palette_convenience.cr` with full implementation
- Implement all missing methods:
  - `get_palette_channel` - Fiber-based async extraction
  - `get_palette_with_stats` - Return palette with counts and percentages
  - `get_palette_color_thief` - Return hex strings for compatibility
  - `get_color` methods - Extract single dominant color

### Phase 2: Fix Thread Safety Issues
- Redesign `HistogramPool` with proper synchronization
- Add mutex protection for shared histogram modification
- Ensure all parallel processing paths are race-free

### Phase 3: Fix Error Handling
- Replace sentinel values with proper error propagation
- Unify error handling across all APIs
- Make Result types consistent

### Phase 4: Fix Algorithmic Issues
- Correct YIQ quantization math
- Optimize VBox.split with cached counts
- Remove runtime type checks

### Phase 5: Verification
- Ensure all existing tests pass
- Add comprehensive thread safety tests
- Verify performance

## Impact Assessment

### Breaking Changes
- None expected - this is fixing broken functionality

### Compatibility
- All existing API signatures remain the same
- Tests should pass after fixes
- No version increment until verified

### Performance
- Thread safety fixes may have minor performance impact
- Algorithmic optimizations should improve performance
- Overall impact expected to be neutral or positive

## Success Criteria

1. Code compiles without errors
2. All existing tests pass
3. No race conditions in parallel processing
4. Error handling is consistent across all APIs
5. Performance is maintained or improved
6. Thread safety is verified through testing
