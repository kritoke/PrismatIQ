# Implementation Tasks: Fix Incomplete Refactor and Thread Safety

## Status Legend
- [ ] Not started
- [~] In progress
- [x] Completed
- [!] Blocked

## Phase 1: Complete Missing Implementation

### 1.1 Create PaletteConvenience Class
- [ ] Create file `src/prismatiq/core/palette_convenience.cr`
- [ ] Implement `initialize(@config : Config = Config.default)`
- [ ] Implement `get_palette_channel(path, options) : Channel(Array(RGB))`
  - [ ] Use Crystal fibers for async execution
  - [ ] Create channel with buffer size 1
  - [ ] Spawn fiber to perform extraction
  - [ ] Send result through channel
  - [ ] Handle exceptions gracefully
  - [ ] Close channel when done
- [ ] Implement `get_palette_with_stats(pixels, width, height, options) : Tuple(Array(PaletteEntry), Int32)`
  - [ ] Call PaletteExtractor to build histogram
  - [ ] Extract palette colors
  - [ ] Build PaletteEntry array with counts and percentages
  - [ ] Return tuple of entries and total pixels
- [ ] Implement `get_palette_color_thief(pixels, width, height, options) : Array(String)`
  - [ ] Extract palette using PaletteExtractor
  - [ ] Convert RGB values to hex strings
  - [ ] Return array of hex colors
- [ ] Implement `get_color_from_path(path) : RGB`
  - [ ] Create Options with color_count: 1
  - [ ] Extract single-color palette
  - [ ] Return first color or fallback
- [ ] Implement `get_color_from_io(io) : RGB`
  - [ ] Create Options with color_count: 1
  - [ ] Extract from IO
  - [ ] Return first color or fallback
- [ ] Implement `get_color(img) : RGB`
  - [ ] Handle CrImage::Image type
  - [ ] Handle String (path) type
  - [ ] Handle IO type
  - [ ] Return first color or fallback
- [ ] Implement private helper `build_palette_entries(palette, histo, total_pixels)`
  - [ ] Map each RGB to PaletteEntry
  - [ ] Calculate count from histogram
  - [ ] Calculate percentage
  - [ ] Return array of entries

### 1.2 Verify Compilation
- [ ] Run `crystal build src/prismatiq.cr` - should succeed
- [ ] Run `crystal spec` - should at least compile (may have test failures)
- [ ] Check for any missing dependencies or imports

## Phase 2: Fix Thread Safety Issues

### 2.1 Fix HistogramPool
- [ ] Add `@mutex : Mutex` field to HistogramPool
- [ ] Update `initialize` to create mutex
- [ ] Wrap `acquire` method body in `@mutex.synchronize`
- [ ] Wrap `release` method body in `@mutex.synchronize`
- [ ] Wrap `size` method body in `@mutex.synchronize`
- [ ] Wrap `clear` method body in `@mutex.synchronize`
- [ ] Wrap `stats` method body in `@mutex.synchronize`
- [ ] Verify no deadlock conditions exist

### 2.2 Verify Parallel Processing Safety
- [ ] Review `PaletteExtractor.build_histo_from_buffer`
- [ ] Confirm each fiber gets unique histogram index
- [ ] Confirm merge happens after all fibers complete
- [ ] Check for any shared mutable state in processing loop
- [ ] Add comments documenting thread safety guarantees

### 2.3 Create Thread Safety Tests
- [ ] Create `spec/thread_safety_spec.cr`
- [ ] Test concurrent histogram pool access
- [ ] Test parallel extraction produces consistent results
- [ ] Test with different thread counts (1, 2, 4, 8)
- [ ] Test with large images to force parallelization
- [ ] Run tests with stress testing (multiple iterations)

## Phase 3: Fix Error Handling

### 3.1 Remove Sentinel Values
- [ ] Identify all places where `[RGB.new(0,0,0)]` is returned as error
- [ ] Replace with proper exception raising or Result types
- [ ] Update `get_palette(img)` in prismatiq.cr to propagate errors
- [ ] Update `PaletteConvenience` methods to handle errors properly

### 3.2 Unify Result Types
- [ ] Audit all public API methods
- [ ] Ensure `get_palette_or_error` variants use Result consistently
- [ ] Ensure `get_palette_v2` variants use Result(Error) consistently
- [ ] Document which methods raise vs return Result

### 3.3 Add Error Context
- [ ] Enhance error messages with actionable information
- [ ] Include file paths, dimensions, parameter values in errors
- [ ] Ensure errors are catchable and meaningful

## Phase 4: Fix Algorithmic Issues

### 4.1 Fix YIQ Quantization
- [ ] Review current `YIQConverter.quantize_from_rgb` implementation
- [ ] Verify scaling math is correct for all three components
- [ ] Add unit tests for edge cases (0, 0, 0), (255, 255, 255), etc.
- [ ] Verify round-trip conversion (RGB -> YIQ -> quantized -> back)
- [ ] Update comments to document the scaling math

### 4.2 Optimize VBox Operations
- [ ] Profile VBox.split to identify bottlenecks
- [ ] Consider caching frequently accessed values
- [ ] Optimize `get_indices` to avoid array allocations
- [ ] Optimize `recalc_count` to use cached data if possible
- [ ] Add benchmarks for VBox operations

### 4.3 Remove Runtime Type Checks
- [ ] Find `sort_by_popularity` method in PaletteExtractor
- [ ] Remove `is_a?` checks on histogram parameter
- [ ] Use proper type annotations at compile time
- [ ] Verify histogram type is consistent throughout codebase

## Phase 5: Verification and Testing

### 5.1 Run Existing Tests
- [ ] `crystal spec spec/palette_stats_spec.cr` - should pass
- [ ] `crystal spec spec/prismatiq_spec.cr` - should pass
- [ ] `crystal spec spec/features_spec.cr` - should pass
- [ ] `crystal spec spec/accessibility_spec.cr` - should pass
- [ ] `crystal spec spec/thread_safe_cache_spec.cr` - should pass
- [ ] `crystal spec spec/validation_spec.cr` - should pass
- [ ] `crystal spec spec/histogram_pool_spec.cr` - should pass
- [ ] `crystal spec spec/yiq_converter_spec.cr` - should pass
- [ ] `crystal spec spec/tempfile_helper_spec.cr` - should pass
- [ ] `crystal spec spec/ico_spec.cr` - should pass
- [ ] `crystal spec spec/prismatiq/ico_spec.cr` - should pass
- [ ] `crystal spec spec/prismatiq/color_extractor_spec.cr` - should pass
- [ ] `crystal spec spec/edge_cases_spec.cr` - should pass
- [ ] `crystal spec spec/theme_detector_spec.cr` - should pass
- [ ] `crystal spec spec/accessibility_calculator_spec.cr` - should pass
- [ ] `crystal spec spec/theme_spec.cr` - should pass
- [ ] `crystal spec spec/result_spec.cr` - should pass
- [ ] Run full suite: `crystal spec` - should all pass

### 5.2 Performance Verification
- [ ] Run `crystal run bench/benchmark.cr`
- [ ] Compare performance before/after changes
- [ ] Ensure no significant performance regression
- [ ] Profile memory usage
- [ ] Check for memory leaks

### 5.3 Code Quality Checks
- [ ] Run `crystal tool format --check`
- [ ] Run any linters if configured
- [ ] Check for compiler warnings
- [ ] Review code for clarity and maintainability

### 5.4 Integration Testing
- [ ] Test with example images
- [ ] Test with different image formats (PNG, JPG, BMP, ICO)
- [ ] Test with edge cases (small images, large images, transparent images)
- [ ] Test examples in `examples/` directory
- [ ] Test color_thief_adapter example

## Phase 6: Documentation Updates

### 6.1 Update Inline Documentation
- [ ] Ensure all public methods have proper doc comments
- [ ] Update thread safety documentation if behavior changed
- [ ] Document any new error handling behavior
- [ ] Update examples in doc comments if needed

### 6.2 Update External Documentation
- [ ] Review README.md for accuracy
- [ ] Update CHANGELOG.md with fix details
- [ ] Update CURRENT_API_SURFACE.md if needed

## Phase 7: Final Verification

### 7.1 Full Test Suite
- [ ] Run `crystal spec` one final time
- [ ] All tests must pass
- [ ] No flaky tests

### 7.2 Code Review
- [ ] Review all changes for correctness
- [ ] Check for any introduced bugs
- [ ] Verify error handling is comprehensive
- [ ] Verify thread safety is complete

### 7.3 Merge Preparation
- [ ] Squash commits if needed
- [ ] Write comprehensive commit message
- [ ] Create pull request or prepare for merge
- [ ] DO NOT increment version number yet (per user request)

## Notes

### Critical Path
The most critical tasks are:
1. Creating `palette_convenience.cr` (Phase 1.1) - without this, code doesn't compile
2. Fixing thread safety (Phase 2.1) - without this, code is unsafe
3. Running tests (Phase 5.1) - to verify everything works

### Dependencies
- Phase 2 depends on Phase 1 (need compiling code to test thread safety)
- Phase 3 depends on Phase 1 (need compiling code to fix errors)
- Phase 4 depends on Phase 1 (need compiling code to fix algorithms)
- Phase 5 depends on Phases 1-4 (need all fixes to pass tests)
- Phase 6 can be done in parallel with Phase 5
- Phase 7 is final verification before merge

### Estimated Effort
- Phase 1: 2-3 hours (create missing implementation)
- Phase 2: 1-2 hours (add mutex synchronization)
- Phase 3: 1-2 hours (unify error handling)
- Phase 4: 2-3 hours (fix algorithms)
- Phase 5: 1-2 hours (testing and verification)
- Phase 6: 1 hour (documentation)
- Phase 7: 1 hour (final verification)

Total: 9-14 hours of focused work

### Risk Mitigation
- All work is on a feature branch - easy to rollback
- No version increment until verified - no impact on releases
- Incremental commits allow bisecting if issues arise
- Tests provide safety net for refactoring
