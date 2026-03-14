## Context

The PrismatIQ codebase has evolved organically, resulting in mixed error handling patterns. Some methods return sentinel values like `[RGB.new(0,0,0)]` while newer methods use `Result(Array(RGB), Error)`. This inconsistency creates confusion for API users and potential runtime issues when error states are not properly handled. Additionally, tempfile cleanup uses best-effort approaches that could leave orphaned files, and some performance-critical loops could benefit from optimization.

## Goals / Non-Goals

**Goals:**
1. Standardize all public API methods to return `Result(Array(RGB), Error)` for consistent error handling
2. Implement robust tempfile cleanup with atomic operations and timeout-based orphan handling
3. Optimize histogram building in pixel processing loops
4. Add comprehensive documentation examples to all public APIs
5. Improve type safety with explicit return types

**Non-Goals:**
- Breaking existing functionality (backward compatibility maintained via deprecation)
- Changing the core color extraction algorithm
- Adding new color space support
- Modifying the internal module structure beyond the affected files

## Decisions

### D1: Error Handling Standardization
**Decision**: Migrate all legacy APIs to return `Result(Array(RGB), Error)` while maintaining backward compatibility through deprecated wrapper methods.

**Rationale**: This approach:
- Provides explicit error information to callers
- Maintains backward compatibility during migration
- Follows Crystal best practices for error handling
- Is already partially implemented in v2 APIs

**Alternative considered**: Throw exceptions for all errors - Rejected because Result types are more idiomatic for recoverable errors and allow callers to handle failures gracefully without try-catch blocks.

### D2: Tempfile Cleanup Strategy
**Decision**: Implement a two-phase cleanup approach: immediate cleanup in ensure block plus a background fiber for orphaned tempfile detection and removal.

**Rationale**: 
- Immediate cleanup handles the common case
- Background cleanup catches edge cases where ensure doesn't execute (crashes, signals)
- Uses Crystal's built-in fiber concurrency without additional dependencies

**Alternative considered**: Using at-exit handlers - Rejected because they don't handle crashes gracefully and can interfere with testing.

### D3: Histogram Optimization
**Decision**: Add loop unrolling hints and eliminate redundant bounds checks in `process_pixel_range`.

**Rationale**:
- The inner loop is performance-critical (runs for every pixel sampled)
- Crystal's `@[AlwaysInline]` hint helps the compiler
- Pre-computing slice bounds avoids repeated method calls

**Alternative considered**: SIMD vectorization - Not practical in Crystal without external libraries; the current algorithm is already well-optimized.

### D4: Documentation Approach
**Decision**: Add inline examples to all public method docstrings following the existing documentation pattern.

**Rationale**:
- Maintains consistency with existing documentation style
- Examples are more valuable than prose descriptions
- Makes the API self-documenting

## Risks / Trade-offs

**[Risk]** Migration may cause confusion during transition period
→ **Mitigation**: Clear deprecation notices with migration examples in CHANGELOG

**[Risk]** Background cleanup fiber may consume resources
→ **Mitigation**: Use low-frequency polling (every 60 seconds) and limit to temp directory files matching prismatiq prefix

**[Risk]** Performance optimizations may reduce code readability
→ **Mitigation**: Add comments explaining the optimization rationale; keep optimization localized to hot paths only

**[Risk]**: Breaking change for users who rely on sentinel values
→ **Mitigation**: Keep legacy methods as deprecated wrappers until v0.7.0; provide clear migration path in documentation

## Migration Plan

1. **Phase 1** (This change): Add new Result-returning methods alongside existing ones
2. **Phase 2** (v0.6.x): Add deprecation notices to legacy methods
3. **Phase 3** (v0.7.0): Remove deprecated methods

No rollback needed as this is additive change with deprecation path.
