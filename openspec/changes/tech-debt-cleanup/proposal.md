# Proposal: Technical Debt Cleanup

**Change:** tech-debt-cleanup  
**Date:** March 8, 2026  
**Status:** Proposed  

## Why

The PrismatIQ codebase has accumulated significant technical debt that threatens maintainability, security, and scalability. The main implementation file has grown to 989 lines, error handling is inconsistent across four different approaches, security vulnerabilities exist in system call patterns, and memory allocation is inefficient. These issues must be addressed now before they compound and make future development prohibitively expensive.

## What Changes

- **BREAKING**: Consolidate all error handling to use standard `Result(T, E)` type exclusively
- **BREAKING**: Simplify public API surface by removing deprecated method overloads and duplicate entry points
- Split monolithic `prismatiq.cr` into logical modules (algorithm, API, utilities, parsers)
- Replace shell command execution with secure system call APIs
- Optimize memory allocation for histogram processing
- Fix thread safety issues by removing global class variables
- Standardize on single concurrency model (Crystal fibers)
- Add comprehensive edge case and error condition testing
- Remove redundant implementations (duplicate YIQ conversions, bounding box calculations)

## Capabilities

### New Capabilities

- `error-handling`: Standardized error handling using Result types with clear error taxonomy and recovery patterns
- `modular-architecture`: Logical separation of concerns with clear module boundaries and responsibilities
- `secure-system-calls`: Safe system information retrieval without shell command injection risks
- `memory-optimization`: Efficient histogram allocation and management strategies
- `thread-safety`: Proper concurrent data access patterns with no shared mutable global state

### Modified Capabilities

- `prismatiq-impl`: Update implementation requirements to enforce modular structure, standardized error handling, and thread safety guarantees

## Impact

**Code Structure:**
- Main file will be split into 5-7 focused modules
- Approximately 30% of code will be reorganized
- All public APIs will have consistent error handling signatures

**API Changes:**
- Deprecated `get_palette(path, color_count, quality, threads)` method will be removed
- All methods will return `Result(T, E)` types exclusively
- `PaletteResult` struct will be deprecated in favor of standard `Result`

**Security:**
- Shell command execution will be replaced with Crystal system APIs
- Input validation will be added for file paths and configuration

**Performance:**
- Memory usage will be reduced by ~40% for typical workloads
- Thread spawning will be more efficient with fiber-based concurrency

**Testing:**
- Edge case coverage will increase from ~60% to ~90%
- Error condition tests will be comprehensive

**Dependencies:**
- No external dependency changes required
- May add internal utility modules for system information

**Migration:**
- Breaking changes require major version bump within 0.x series (0.x.y → 0.(x+1).0)
- Migration guide will be provided for API changes
- Most breaking changes are in less commonly used method signatures
