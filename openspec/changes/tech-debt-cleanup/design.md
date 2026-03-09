# Design: Technical Debt Cleanup

**Change:** tech-debt-cleanup  
**Date:** March 8, 2026  
**Status:** Draft  

## Context

The PrismatIQ library is a color palette extraction tool built in Crystal. The codebase has evolved organically from a weekend project into a production library, accumulating technical debt along the way:

**Current State:**
- Main implementation file: `src/prismatiq.cr` (989 lines)
- Error handling: 4 different approaches (sentinel values, custom Result, exceptions, standard Result)
- Concurrency: Mixed Thread.new and spawn/fibers
- Security: Shell command execution via backticks
- Memory: Fixed 32KB histogram allocation per thread
- Global state: Class variables in accessibility/theme modules
- Testing: ~60% edge case coverage

**Stakeholders:**
- Library users consuming the public API
- Contributors maintaining the codebase
- Security auditors reviewing the implementation

**Constraints:**
- Must maintain backward compatibility where possible
- No external dependency changes
- Performance must not degrade significantly
- Crystal language idioms and standard library limitations

## Goals / Non-Goals

**Goals:**
- Reduce main file to <300 lines by extracting logical modules
- Achieve 100% Result-based error handling in public API
- Eliminate all shell command execution
- Reduce memory allocation by 40% for typical workloads
- Standardize on fiber-based concurrency
- Remove all global mutable class variables
- Achieve 90%+ edge case test coverage
- Provide clear migration path for breaking changes

**Non-Goals:**
- Complete rewrite of the MMCQ algorithm (only refactor structure)
- Performance optimization beyond memory allocation improvements
- Adding new features or capabilities
- Changing the core color quantization approach
- Modifying the YIQ color space implementation

## Decisions

### 1. Module Structure

**Decision:** Split into 6 focused modules with clear boundaries

**Structure:**
```
src/
  prismatiq.cr              (250 lines - main API + config)
  prismatiq/
    types.cr                (80 lines - RGB, VBox, Options, Result types)
    algorithm/
      mmcq.cr               (200 lines - MMCQ quantization)
      priority_queue.cr     (60 lines - max-heap implementation)
      color_space.cr        (100 lines - YIQ conversions)
    core/
      histogram.cr          (120 lines - histogram building/merging)
      palette_extractor.cr  (80 lines - palette extraction orchestration)
    utils/
      system_info.cr        (40 lines - CPU count, cache detection)
      image_reader.cr       (60 lines - file/IO/image loading)
    parsers/
      ico_parser.cr         (already modular)
    accessibility.cr        (already exists)
    theme.cr                (already exists)
```

**Rationale:**
- Each module has single responsibility
- Clear dependency graph (algorithm → core → utils → types)
- Easier to test in isolation
- Natural extension points for future features

**Alternatives Considered:**
- *Flatter structure with all in src/prismatiq/*: Harder to navigate, less clear boundaries
- *Single algorithm.cr file*: Would still be 360+ lines, mixes concerns
- *Keep monolithic but add comments*: Doesn't solve maintainability issues

### 2. Error Handling Migration

**Decision:** Three-phase migration with deprecation warnings

**Phase 1: Add Result-returning variants (0.6.0)**
```crystal
# New preferred API
def get_palette(path : String, options : Options) : Result(Array(RGB), Error)
def get_palette!(path : String, options : Options) : Array(RGB) # raises on error

# Keep old API with deprecation
@[Deprecated("Use get_palette(path, options) instead")]
def get_palette(path, color_count, quality, threads)
```

**Phase 2: Remove deprecated methods (0.7.0)**
- Remove old positional argument overloads
- Remove `PaletteResult` struct
- Remove sentinel value `[RGB.new(0, 0, 0)]`

**Phase 3: Clean up internal error handling (0.8.0)**
- Standardize all internal methods on Result types
- Add comprehensive error taxonomy

**Error Taxonomy:**
```crystal
enum ErrorType
  FileNotFound
  InvalidImagePath
  UnsupportedFormat
  CorruptedImage
  InvalidOptions
  ProcessingFailed
end

struct Error
  getter type : ErrorType
  getter message : String
  getter context : Hash(String, String)?
end
```

**Rationale:**
- Gradual migration reduces breakage
- Clear error types enable better error handling
- `!` suffix convention for raising variants is idiomatic Crystal

**Alternatives Considered:**
- *Big-bang migration*: Too disruptive for users
- *Keep multiple error types*: Confusing, maintenance burden
- *Exceptions only*: Not idiomatic for expected failures (file not found)

### 3. Concurrency Model

**Decision:** Migrate to fiber-based concurrency with channels

**Implementation:**
```crystal
# Replace Thread.new with spawn
def build_histogram_parallel(pixels : Array(RGB), quality : Int32) : Hash(Int32, Int32)
  channel = Channel(Hash(Int32, Int32)).new(threads)
  
  pixels.each_slice(chunk_size) do |chunk|
    spawn do
      histogram = build_histogram_chunk(chunk, quality)
      channel.send(histogram)
    end
  end
  
  # Merge results
  merge_histograms(channel, threads)
end
```

**Rationale:**
- Fibers are lighter weight (8KB stack vs 512KB+ for threads)
- Crystal's scheduler handles load balancing
- Channels provide clean communication pattern
- Aligns with Crystal best practices

**Alternatives Considered:**
- *Keep Thread.new*: Heavier weight, less idiomatic
- *Thread pool pattern*: More complex, Crystal already has fiber scheduler
- *Single-threaded only*: Would lose parallelism benefits

### 4. Memory Optimization

**Decision:** Adaptive histogram allocation with lazy merging

**Strategy:**
1. **Lazy histogram initialization**: Only allocate when first pixel added
2. **Chunk-based allocation**: Use smaller chunks for small images
3. **In-place merging**: Merge histograms without intermediate copies
4. **Histogram pooling**: Reuse histogram objects across chunks

**Implementation:**
```crystal
class HistogramPool
  @pool = [] of Hash(Int32, Int32)
  
  def acquire : Hash(Int32, Int32)
    @pool.pop? || Hash(Int32, Int32).new(0)
  end
  
  def release(histogram : Hash(Int32, Int32))
    histogram.clear
    @pool << histogram
  end
end
```

**Expected Savings:**
- Small images (<1MP): 90% reduction (1 histogram vs 16)
- Medium images (1-5MP): 50% reduction (pooling + lazy allocation)
- Large images (>5MP): 25% reduction (in-place merging)

**Rationale:**
- No algorithm changes, just allocation strategy
- Maintains parallelism benefits
- Reduces GC pressure

**Alternatives Considered:**
- *Shared histogram with mutex*: Contention would kill performance
- *Single histogram, single thread*: Lose parallelism
- *Pre-allocated fixed pool*: Wasteful for small images

### 5. Security Improvements

**Decision:** Replace shell commands with Crystal system APIs

**Current (vulnerable):**
```crystal
module CPU
  def self.count : Int32
    out = (`sysctl -n hw.ncpu`) # Shell injection risk pattern
    out.strip.to_i
  end
end
```

**New (secure):**
```crystal
module SystemInfo
  def self.cpu_count : Int32
    {% if flag?(:darwin) %}
      # Use sysctl syscall directly
      LibC.sysctlbyname("hw.ncpu", out count, ...)
      count
    {% elsif flag?(:linux) %}
      # Read from /proc/cpuinfo
      File.read("/proc/cpuinfo").scan(/^processor/).size
    {% else %}
      1 # Fallback
    {% end %}
  end
end
```

**Additional Security Measures:**
- Validate file paths don't escape expected directories
- Add maximum file size limits (prevent DoS)
- Sanitize Options input parameters

**Rationale:**
- No shell = no shell injection
- Crystal's LibC bindings are safe
- Compile-time platform detection is efficient

**Alternatives Considered:**
- *Keep shell but sanitize*: Still risky, harder to audit
- *External system info library*: Unnecessary dependency
- *Hardcode to 1 CPU*: Lose performance optimization

### 6. Global State Elimination

**Decision:** Instance-based caching with dependency injection

**Current (problematic):**
```crystal
module Accessibility
  @@luminance_cache = ThreadSafeCache(String, Float64).new
  
  def self.luminance(color : RGB) : Float64
    @@luminance_cache.get_or_set(color.hex) { compute_luminance(color) }
  end
end
```

**New (thread-safe):**
```crystal
class AccessibilityCalculator
  @luminance_cache = ThreadSafeCache(String, Float64).new
  
  def luminance(color : RGB) : Float64
    @luminance_cache.get_or_set(color.hex) { compute_luminance(color) }
  end
end

# Users create their own instances
calculator = AccessibilityCalculator.new
lum = calculator.luminance(color)
```

**Migration:**
- Keep module-level convenience methods that delegate to singleton instance
- Document that users should create instances for thread safety
- Add deprecation warnings to module-level methods

**Rationale:**
- Instance state is inherently thread-safe
- Clearer ownership and lifecycle
- Testable (can create fresh instances)

**Alternatives Considered:**
- *Keep globals with better locking*: Still has race conditions
- *Remove caching entirely*: Performance regression
- *Thread-local storage*: Complex, memory overhead

### 7. Testing Strategy

**Decision:** Comprehensive edge case testing with property-based tests

**Test Categories:**
1. **Unit tests**: Each module in isolation (target: 80% coverage)
2. **Integration tests**: End-to-end API testing (target: 90% coverage)
3. **Property-based tests**: Random image generation for algorithm validation
4. **Error condition tests**: Every error path covered

**New Test Cases:**
- Corrupted image files (truncated, invalid headers)
- Extremely large images (>50MP)
- Zero-byte files
- Invalid color counts (0, negative, >256)
- Invalid quality values
- Thread safety validation (concurrent access tests)
- Memory leak detection (long-running tests)

**Rationale:**
- Edge cases are where bugs hide
- Property-based tests find algorithm issues
- Error tests prevent regressions

**Alternatives Considered:**
- *Manual testing only*: Not scalable
- *Fewer tests, rely on types*: Crystal types don't catch logic errors
- *Integration tests only*: Hard to debug failures

## Risks / Trade-offs

### Risk 1: Breaking Changes Impact Adoption
**Risk:** Users may delay upgrading due to breaking API changes  
**Mitigation:**
- Long deprecation period (2-3 minor versions)
- Comprehensive migration guide with examples
- Automated migration script for common patterns
- Semantic versioning clearly communicates breaks

### Risk 2: Performance Regression During Refactor
**Risk:** Code reorganization may inadvertently impact performance  
**Mitigation:**
- Maintain performance test suite
- Benchmark before/after each major change
- Profile memory usage at each step
- Keep algorithm implementation unchanged initially

### Risk 3: Fiber Migration Complexity
**Risk:** Fiber-based concurrency may have subtle differences from Thread-based  
**Mitigation:**
- Extensive parallel processing tests
- Test on multiple platforms (Linux, macOS)
- Monitor for deadlocks/race conditions
- Keep Thread-based code available initially as fallback

### Risk 4: Test Coverage Gaps
**Risk:** New tests may miss edge cases  
**Mitigation:**
- Code coverage metrics enforcement (>90% required)
- Property-based testing for algorithm validation
- Fuzz testing for parsers
- Code review checklist for test completeness

### Risk 5: Migration Guide Incomplete
**Risk:** Users struggle to upgrade due to missing migration documentation  
**Mitigation:**
- Test migration guide with real codebases
- Provide before/after examples for each breaking change
- Create GitHub issue template for migration problems
- Offer community support channel

## Migration Plan

### Phase 0: Preparation (v0.5.x)
- [ ] Add comprehensive test coverage for current implementation
- [ ] Create performance benchmark suite
- [ ] Document current API surface
- [ ] Set up CI/CD for automated testing

### Phase 1: Non-Breaking Foundation (v0.6.0)
- [ ] Extract modules (no API changes)
- [ ] Add new Result-based API methods alongside old ones
- [ ] Add deprecation warnings to old methods
- [ ] Replace shell commands with secure alternatives
- [ ] Migrate to fiber-based concurrency (internal only)
- [ ] Add instance-based caching (keep module-level shims)
- [ ] Release with migration guide

**Timeline:** 2-3 weeks  
**Risk:** Low (backward compatible)  
**Rollback:** Easy (revert to v0.5.x)

### Phase 2: Breaking Changes (v0.7.0)
- [ ] Remove deprecated API methods
- [ ] Remove `PaletteResult` struct
- [ ] Remove sentinel error values
- [ ] Remove module-level cache accessors
- [ ] Update all documentation
- [ ] Release with detailed migration guide

**Timeline:** 1-2 weeks  
**Risk:** Medium (breaking changes)  
**Rollback:** Not possible (major version bump)

### Phase 3: Optimization & Polish (v0.8.0)
- [ ] Implement histogram pooling
- [ ] Optimize memory allocation patterns
- [ ] Add property-based tests
- [ ] Achieve 90%+ test coverage
- [ ] Performance profiling and optimization
- [ ] Final documentation pass

**Timeline:** 1-2 weeks  
**Risk:** Low (no API changes)  
**Rollback:** Easy (revert to v0.7.x)

### Phase 4: Validation (v0.9.0)
- [ ] Beta testing with key users
- [ ] Performance benchmarks vs v0.5.x
- [ ] Security audit
- [ ] Documentation review
- [ ] Prepare for v1.0.0 release

**Timeline:** 2 weeks  
**Risk:** Low (stabilization only)  

## Open Questions

1. **Error type granularity**: Should we have specific error types for each failure mode (e.g., `CorruptedImageError`, `UnsupportedFormatError`) or keep it simpler with a generic `Error` struct?

2. **Instance creation ergonomics**: Should `AccessibilityCalculator` and similar classes provide a convenient singleton for simple use cases, or force instance creation?

3. **Histogram pooling strategy**: Should the pool be per-extraction or global? Per-extraction is simpler but may allocate more.

4. **Fiber scheduler configuration**: Should we expose fiber scheduling options to users, or keep it internal?

5. **Migration tooling**: Should we provide an automated code migration tool, or rely on manual migration with good documentation?

6. **Performance regression tolerance**: What's the acceptable performance impact during refactoring? 5%? 10%? Any regression?

7. **Thread safety testing**: How do we effectively test thread safety? Stress testing? Formal verification tools?

---

**Next Steps:** Review this design with stakeholders, resolve open questions, then proceed to specs creation.
