## Context

The PrismatIQ codebase is a Crystal library for color palette extraction and accessibility analysis. Current issues include:
- Multiple error handling patterns (sentinel values, exceptions, Result types, PaletteResult struct)
- Duplicated caching logic with manual mutex management in Accessibility and Theme modules  
- Redundant configuration validation between `validate_params` method and `Options#validate!`
- Scattered YIQ conversion logic across multiple methods
- Overly complex 662-line ICO module with mixed concerns
- Inconsistent API surface with multiple similar method signatures

The codebase follows functional programming principles in some areas but lacks consistency. This design aims to create a more cohesive, maintainable architecture while preserving all existing functionality.

## Goals / Non-Goals

**Goals:**
- Standardize error handling using Crystal's `Result(T, E)` type consistently across all public APIs
- Eliminate code duplication through reusable generic components (ThreadSafeCache, ParallelProcessor)
- Reduce API surface complexity by consolidating parameter handling through Options struct
- Improve modularity by breaking down monolithic components (ICO module) into focused units
- Maintain backward compatibility during transition with deprecation warnings where possible
- Preserve all existing functionality and performance characteristics

**Non-Goals:**
- Adding new features or capabilities beyond what currently exists
- Changing the core MMCQ algorithm or color extraction logic
- Modifying external dependencies or adding new ones
- Breaking changes without clear migration path
- Performance optimizations beyond what comes naturally from cleanup

## Decisions

### Error Handling Standardization
**Decision**: Use `Result(Array(RGB), String)` as the primary return type for all public APIs.

**Rationale**: The existing `Result` type already provides excellent error handling semantics inspired by Rust. Sentinel values `[RGB.new(0, 0, 0)]` are ambiguous and error-prone. The `PaletteResult` struct duplicates `Result` functionality unnecessarily. Standardizing on `Result` provides explicit error handling that's idiomatic in Crystal.

**Alternatives Considered**: 
- Keep sentinel values: Rejected due to ambiguity and poor error handling
- Use exceptions throughout: Rejected because it doesn't allow for graceful error handling in library consumers
- Create custom error enum: Overkill when `Result` already fits perfectly

### Generic Thread-Safe Cache
**Decision**: Create `ThreadSafeCache(K, V)` generic class to replace manual mutex/caching patterns.

**Rationale**: Both Accessibility and Theme modules implement nearly identical caching logic with separate mutexes and hashes. A generic solution eliminates ~30 lines of duplicated code per module and provides a reusable utility for future needs.

**Implementation**: The cache will use lazy computation with `get_or_compute(key, &block)` pattern, ensuring thread-safe initialization and avoiding unnecessary computation.

### API Surface Rationalization  
**Decision**: Reduce public API to minimal core set using only `Options` parameter.

**Rationale**: The current API has multiple overloads (`get_palette(color_count, quality)`, `get_palette(options)`, `get_palette_result(...)`, etc.) creating maintenance burden and confusion. A single parameter object with named fields is clearer and more extensible.

**Migration Strategy**: Initially keep deprecated methods with `@[Deprecated]` annotations pointing to new APIs, then remove in next major version.

### ICO Module Restructuring
**Decision**: Break ICO module into `ICOFile`, `ICOEntry`, and `BMPParser` components.

**Rationale**: The current 662-line file mixes PNG handling, BMP parsing, bit manipulation, and error handling. Separating concerns improves testability and maintainability. PNG handling can leverage existing CrImage capabilities more effectively.

**Structure**:
- `ICOFile`: High-level interface, selects best entry
- `ICOEntry`: Represents individual icon entries with metadata  
- `BMPParser`: Dedicated BMP/DIB format parser
- `PNGExtractor`: Leverages CrImage for PNG-encoded entries

### Parallel Processing Infrastructure
**Decision**: Extract generic parallel processing into `ParallelProcessor` class.

**Rationale**: The histogram building logic in `build_histo_from_buffer` contains complex thread coordination that could be reused. However, after analysis, this may be over-engineering since the logic is highly specific to histogram processing.

**Revised Decision**: Keep histogram-specific logic inline but extract the chunked merging logic into a private helper method `merge_histogram_chunks(histograms, config)` to reduce cognitive load.

## Risks / Trade-offs

### [Breaking API Changes] → Mitigation: Comprehensive deprecation strategy
Introducing breaking changes to public APIs could impact existing users. Mitigation includes:
- Keeping deprecated methods with clear warnings initially
- Providing detailed migration guide in CHANGELOG
- Version bump to indicate breaking changes
- Thorough testing to ensure new APIs work identically

### [Increased Complexity During Transition] → Mitigation: Incremental implementation  
Maintaining both old and new code paths temporarily increases complexity. Mitigation:
- Implement changes in logical groups (error handling first, then API consolidation)
- Remove deprecated code only after new APIs are stable
- Use feature flags if needed for gradual rollout

### [Performance Regressions] → Mitigation: Benchmark-driven development
Refactoring could inadvertently impact performance. Mitigation:
- Run existing benchmarks before and after each change
- Profile critical paths (MMCQ, histogram building)
- Optimize only if measurable regressions occur

### [Testing Gaps] → Mitigation: Comprehensive test coverage verification
Changes might introduce subtle bugs. Mitigation:
- Ensure all existing tests pass with new implementations
- Add additional tests for edge cases in new components
- Manual verification of color extraction accuracy

## Open Questions

1. Should we maintain the async/channel-based APIs (`get_palette_async`, `get_palette_channel`) or rely on Crystal's built-in concurrency primitives?
2. What's the appropriate timeline for removing deprecated APIs - immediate removal or staged deprecation?
3. Should the generic `ThreadSafeCache` be part of the public API or kept internal to PrismatIQ?
4. How much of the ICO module restructuring should be done in this change vs. deferred to future improvements?