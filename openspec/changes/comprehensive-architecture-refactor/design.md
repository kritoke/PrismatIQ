## Context

The PrismatIQ codebase currently suffers from severe architectural debt that manifests in multiple ways:
- **Monolithic structure**: The main `prismatiq.cr` file is 989 lines long, containing core algorithm, priority queue, MMCQ quantization, public API, configuration management, and thread coordination
- **Inconsistent error handling**: Three different approaches coexist (sentinel values, custom `PaletteResult`, and standard `Result` type)
- **Security vulnerabilities**: Shell-based system calls for CPU detection create potential injection risks
- **Thread safety issues**: Global class variables with `ThreadSafeCache` create potential race conditions
- **Memory inefficiency**: Each thread creates full 32KB histograms regardless of actual data needs
- **API confusion**: Multiple method overloads with different parameter combinations and return types

The current state makes the codebase difficult to maintain, extend, test, and secure. This design addresses these issues through a comprehensive refactoring approach.

## Goals / Non-Goals

**Goals:**
- Establish a modular, maintainable architecture following Crystal best practices
- Implement consistent, explicit error handling using `Result(Array(RGB), String)` across all public APIs
- Eliminate security vulnerabilities by replacing shell commands with proper system APIs
- Ensure true thread safety through instance-based caching instead of global state
- Optimize memory usage and performance through efficient data structures and cache-friendly algorithms
- Provide a clean, consistent public API with minimal overloads
- Add comprehensive input validation and edge case handling
- Implement proper resource cleanup and error recovery mechanisms
- Create comprehensive test coverage for all scenarios including error cases

**Non-Goals:**
- Changing the core MMCQ algorithm logic or color quantization approach
- Adding new features beyond what's required for the refactoring
- Modifying the fundamental YIQ color space conversion mathematics
- Breaking compatibility with the CrImage dependency
- Reimplementing the entire codebase from scratch

## Decisions

### 1. Error Handling Standardization
**Decision**: Use `Result(Array(RGB), String)` as the single error handling pattern for all public APIs.

**Rationale**: The existing `Result` type already provides excellent error handling semantics inspired by Rust. Sentinel values `[RGB.new(0, 0, 0)]` are ambiguous and error-prone. The `PaletteResult` struct duplicates `Result` functionality unnecessarily. Standardizing on `Result` provides explicit error handling that's idiomatic in Crystal.

**Alternatives considered**:
- Keep sentinel values: Creates ambiguity between actual black pixels and errors
- Keep `PaletteResult`: Duplicates existing functionality without benefit
- Use exceptions exclusively: Forces callers to handle exceptions rather than explicit error types

### 2. Modular Architecture
**Decision**: Split the monolithic `prismatiq.cr` into focused modules:
- `core/algorithm.cr`: MMCQ implementation and priority queue
- `core/histogram.cr`: Histogram building and merging logic
- `api/palette_extraction.cr`: Public API methods
- `api/error_handling.cr`: Result type definitions and helpers
- `utils/yiq_converter.cr`: Centralized YIQ conversion logic
- `utils/cpu_detection.cr`: Secure CPU detection without shell commands
- `utils/caching.cr`: Generic `ThreadSafeCache` implementation
- `parsers/ico_parser.cr`: ICO file parsing with proper validation
- `parsers/bmp_parser.cr`: BMP/DIB format parsing

**Rationale**: Single responsibility principle improves maintainability, testing, and understanding. Each module can be developed, tested, and documented independently.

**Alternatives considered**:
- Keep monolithic structure: Maintains current confusion and coupling
- Minimal splitting: Doesn't address the core architectural issues

### 3. Secure System Calls
**Decision**: Replace backtick-based system calls with proper Crystal system APIs or cross-platform library calls.

**Rationale**: Shell commands create potential injection vulnerabilities and are unreliable across platforms. Proper system APIs provide better error handling and security.

**Implementation**: Use Crystal's `Process` module or direct system call bindings where available, with proper fallbacks for unsupported platforms.

### 4. Instance-Based Caching
**Decision**: Replace global class variables (`@@luminance_cache`, `@@theme_cache`) with instance-based caching using dependency injection.

**Rationale**: Global state creates hidden dependencies and makes testing difficult. Instance-based caching allows proper isolation and testability while maintaining thread safety through the `ThreadSafeCache` wrapper.

**Implementation**: Pass cache instances to modules that need them, or use a service locator pattern for optional caching.

### 5. Memory Optimization Strategy
**Decision**: Implement lazy histogram allocation and reuse buffers where possible.

**Rationale**: Creating full 32KB histograms for each thread regardless of actual data needs wastes memory and creates unnecessary GC pressure. Lazy allocation and buffer reuse improve performance and memory usage.

**Implementation**: 
- Only allocate histogram bins that are actually used
- Reuse local histogram buffers in thread pools
- Implement chunked processing with smaller working sets

### 6. API Consolidation
**Decision**: Reduce public API to minimal core set using only `Options` parameter with `Result` return types.

**Rationale**: Multiple overloads create maintenance burden and confusion. A single parameter object with named fields is clearer and more extensible.

**Migration Strategy**: Initially keep deprecated methods with `@[Deprecated]` annotations pointing to new APIs, then remove in next major version.

## Risks / Trade-offs

**[Risk] Breaking changes may affect existing users** → Mitigation: Provide comprehensive migration guide, maintain deprecated APIs with warnings during transition period, and clear versioning strategy

**[Risk] Performance regression during refactoring** → Mitigation: Implement comprehensive benchmarks before and after changes, profile critical paths, and optimize incrementally

**[Risk] Increased complexity in module dependencies** → Mitigation: Use clear dependency injection patterns, avoid circular dependencies, and document module relationships

**[Risk] Incomplete error handling coverage** → Mitigation: Implement comprehensive test suite covering all error scenarios, use static analysis tools, and code review process

**[Risk] Platform-specific system call differences** → Mitigation: Implement proper fallbacks for different platforms, extensive testing on supported platforms, and clear documentation of limitations

**[Risk] Thread safety issues in new concurrent code** → Mitigation: Use established concurrency patterns, extensive stress testing, and consider using Crystal's fiber-based concurrency instead of raw threads where appropriate

## Open Questions

1. Should we implement a complete service locator pattern or stick with simple dependency injection for caching?
2. What's the best approach for CPU detection on Windows without shell commands?
3. Should we add optional compile-time flags for debugging features to reduce production overhead?
4. How should we handle backward compatibility for the ICO parser's error handling?
5. What level of performance optimization is sufficient vs. over-engineering?