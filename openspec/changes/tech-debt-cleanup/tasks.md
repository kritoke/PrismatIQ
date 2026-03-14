# Implementation Tasks: Technical Debt Cleanup

**Change:** tech-debt-cleanup  
**Status:** Ready to Implement  
**Created:** March 8, 2026  

## 1. Setup & Preparation

- [x] 1.1 Create comprehensive test suite for current implementation (baseline coverage)
- [x] 1.2 Set up performance benchmark suite for regression detection
- [x] 1.3 Document current public API surface (all methods, signatures, return types)
- [x] 1.4 Create backup branch for rollback if needed
- [ ] 1.5 Set up CI/CD pipeline with test coverage reporting

## 2. Module Extraction (Non-Breaking)

- [x] 2.1 Create `src/prismatiq/types.cr` and move RGB, VBox, Options structs
- [x] 2.2 Create `src/prismatiq/algorithm/` directory structure
- [x] 2.3 Extract Priority Queue to `src/prismatiq/algorithm/priority_queue.cr`
- [x] 2.4 Extract YIQ color space functions to `src/prismatiq/algorithm/color_space.cr`
- [x] 2.5 Extract MMCQ algorithm to `src/prismatiq/algorithm/mmcq.cr`
- [x] 2.6 Create `src/prismatiq/core/` directory structure
- [x] 2.7 Extract histogram building logic to `src/prismatiq/core/histogram.cr`
- [x] 2.8 Extract palette extraction orchestration to `src/prismatiq/core/palette_extractor.cr`
- [x] 2.9 Create `src/prismatiq/utils/` directory structure
- [x] 2.10 Create `src/prismatiq/utils/image_reader.cr` for file/IO loading (cancelled - CrImage handles this)
- [x] 2.11 Verify main `src/prismatiq.cr` is under 300 lines after extraction (now 295)
- [x] 2.12 Update all require statements in main file
- [x] 2.13 Run full test suite to verify no functionality broken
- [x] 2.14 Update any internal references to moved code

## 3. Error Handling Migration (Phase 1 - Non-Breaking)

- [x] 3.1 Create `src/prismatiq/errors.cr` with Error struct and ErrorType enum
- [x] 3.2 Add Result-returning variants for all public methods with `_result` suffix (get_palette_result, get_palette_or_error)
- [x] 3.3 Add `get_palette_v2(path, options) : Result` method alongside existing methods
- [x] 3.4 Add `get_palette_v2!(path, options) : Array(RGB)` raising variant
- [ ] 3.5 Mark old `get_palette(path, color_count, quality, threads)` as deprecated
- [ ] 3.6 Mark `PaletteResult` struct as deprecated with migration note
- [x] 3.7 Update internal error handling to use Error struct
- [ ] 3.8 Replace sentinel value `[RGB.new(0,0,0)]` with proper Result::Err returns
- [x] 3.9 Add comprehensive error messages with context to all error paths
- [x] 3.10 Write tests for all new Result-returning methods
- [x] 3.11 Write tests for all error scenarios (FileNotFound, CorruptedImage, etc.)
- [ ] 3.12 Verify deprecation warnings appear when using old API

## 4. Security Improvements

- [x] 4.1 Create `src/prismatiq/utils/system_info.cr` module
- [x] 4.2 Implement CPU count detection using Crystal's System.cpu_count (no shell)
- [x] 4.3 Implement CPU count detection for Linux using /proc/cpuinfo (secure)
- [x] 4.4 Add fallback CPU count for unknown platforms
- [x] 4.5 Replace all backtick shell commands with new SystemInfo module
- [x] 4.6 Add file path validation to prevent directory traversal
- [x] 4.7 Add file extension validation for supported formats
- [x] 4.8 Add maximum file size check (100MB limit)
- [x] 4.9 Add Options parameter validation (color_count, quality, threads ranges)
- [x] 4.10 Verify all temp files use secure Tempfile class
- [x] 4.11 Add ensure blocks for temp file cleanup in ICO parser
- [x] 4.12 Remove sensitive data from error messages (use basename only)
- [x] 4.13 Write security-focused tests (invalid paths, oversized files, etc.)

## 5. Memory Optimization

- [x] 5.1 Create `src/prismatiq/core/histogram_pool.cr` class
- [x] 5.2 Implement HistogramPool with acquire/release methods
- [x] 5.3 Add lazy histogram initialization logic
- [x] 5.4 Implement adaptive chunk sizing based on image size
- [x] 5.5 Update histogram building to use pool instead of pre-allocation
- [x] 5.6 Implement in-place histogram merging (no intermediate copies)
- [x] 5.7 Add memory usage metrics logging (debug mode only)
- [x] 5.8 Benchmark memory usage before and after optimization
- [x] 5.9 Verify 25-40% memory reduction on typical workloads
- [x] 5.10 Ensure no memory leaks (all histograms returned to pool)
- [x] 5.11 Test with various image sizes (small, medium, large)

## 6. Thread Safety Improvements

- [x] 6.1 Convert Accessibility module from class variables to instance variables
- [x] 6.2 Create AccessibilityCalculator class with instance-based caching
- [x] 6.3 Add module-level convenience methods that delegate to singleton
- [x] 6.4 Convert Theme module from class variables to instance variables
- [x] 6.5 Create ThemeDetector class with instance-based caching
- [x] 6.6 Add module-level convenience methods that delegate to singleton
- [x] 6.7 Replace Thread.new with spawn for parallel processing
- [x] 6.8 Implement channel-based histogram result collection
- [x] 6.9 Remove all shared mutable state between fibers
- [x] 6.10 Verify ThreadSafeCache works correctly with new instance pattern
- [x] 6.11 Write concurrent access tests (100 fibers accessing same cache)
- [x] 6.12 Write concurrent palette extraction tests
- [x] 6.13 Document thread safety guarantees in code comments

## 7. Testing Enhancement

- [x] 7.1 Add test cases for corrupted image files
- [x] 7.2 Add test cases for zero-byte files
- [ ] 7.3 Add test cases for extremely large images (>50MP)
- [x] 7.4 Add test cases for all error types in ErrorType enum
- [ ] 7.5 Add property-based tests for algorithm validation
- [ ] 7.6 Add fuzz tests for ICO parser
- [ ] 7.7 Add memory leak detection tests (long-running)
- [ ] 7.8 Add race condition detection tests
- [ ] 7.9 Verify test coverage exceeds 90% for edge cases
- [x] 7.10 Verify test coverage exceeds 90% for error paths (validation_spec.cr: 23 tests)
- [ ] 7.11 Add performance regression tests
- [ ] 7.12 Document test strategy and coverage requirements

## 8. Documentation Updates

- [x] 8.1 Update README.md with new Result-based API examples
- [x] 8.2 Add migration guide section to README.md  
- [x] 8.3 Document all ErrorType variants and when they occur
- [x] 8.4 Document thread safety guarantees for each module (via source code comments)
- [x] 8.5 Document memory optimization strategies (via source code comments)
- [ ] 8.6 Add examples for creating instances vs using module methods
- [x] 8.7 Document deprecation timeline (in CHANGELOG.md and source comments)
- [x] 8.8 Add API reference documentation for all public methods (via crystal docs)
- [x] 8.9 Update inline code comments for new module structure
- [x] 8.10 Create CHANGELOG.md entry for v0.6.0 release

## 9. Breaking Changes (Phase 2 - v0.7.0)

- [ ] 9.1 Remove deprecated `get_palette(path, color_count, quality, threads)` method
- [ ] 9.2 Remove `PaletteResult` struct
- [ ] 9.3 Remove all sentinel error value patterns
- [ ] 9.4 Remove deprecated module-level cache accessors (keep convenience only)
- [ ] 9.5 Rename `_result` suffix methods to be primary (remove old non-Result methods)
- [ ] 9.6 Update all documentation to reflect breaking changes
- [ ] 9.7 Create detailed migration guide with before/after examples
- [ ] 9.8 Update version to 0.7.0 in shard.yml
- [ ] 9.9 Run full test suite after breaking changes
- [ ] 9.10 Verify no references to removed code exist

## 10. Final Polish (Phase 3 - v0.8.0)

- [ ] 10.1 Code review all changes for consistency and quality
- [ ] 10.2 Profile performance and verify no regression
- [ ] 10.3 Profile memory usage and verify 25-40% improvement
- [ ] 10.4 Run security audit on all changes
- [ ] 10.5 Final documentation review and polish
- [ ] 10.6 Verify all deprecation warnings are helpful and accurate
- [ ] 10.7 Test migration path with sample user code
- [ ] 10.8 Update CHANGELOG.md for v0.8.0 release
- [ ] 10.9 Create release notes highlighting improvements
- [ ] 10.10 Tag release v0.8.0 in git

## 11. Validation & Release (v0.9.0)

- [ ] 11.1 Beta testing with key users
- [ ] 11.2 Collect and address beta feedback
- [ ] 11.3 Run comprehensive performance benchmarks vs v0.5.x
- [ ] 11.4 Run security audit with external tools
- [ ] 11.5 Verify all test coverage metrics met (>90%)
- [ ] 11.6 Final documentation review
- [ ] 11.7 Update CHANGELOG.md for v0.9.0 release
- [ ] 11.8 Prepare for v1.0.0 release planning
- [ ] 11.9 Tag release v0.9.0 in git
- [ ] 11.10 Announce release with migration guide

---

**Total Tasks:** 130  
**Estimated Timeline:** 6-8 weeks  
**Breaking Changes:** v0.7.0 (Phase 2)  
**Stable Release:** v0.9.0 (Phase 4)
