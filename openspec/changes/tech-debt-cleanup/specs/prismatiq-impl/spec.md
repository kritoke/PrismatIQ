# Delta Spec: PrismatIQ Implementation

**Date:** March 8, 2026  
**Status:** Modification Proposed  
**Author:** OpenSpec Workflow  

## MODIFIED Requirements

### Requirement: Modular Architecture
The implementation SHALL be organized into focused modules with clear separation of concerns and no circular dependencies.

**Previous:** Single file implementation with algorithm, API, and utilities mixed  
**Updated:** Split into logical modules:
- `prismatiq.cr` - Public API and configuration (<300 lines)
- `prismatiq/types.cr` - Data type definitions (RGB, VBox, Options, Error)
- `prismatiq/algorithm/` - MMCQ quantization and color space logic
- `prismatiq/core/` - Histogram building and palette extraction
- `prismatiq/utils/` - System info, image reading, file I/O
- `prismatiq/parsers/` - Image format parsers (ICO, etc.)

#### Scenario: Module dependency validation
- **WHEN** analyzing module import graph
- **THEN** dependencies flow in one direction: utils → types, core → utils, algorithm → types, main → all

#### Scenario: Main file size constraint
- **WHEN** measuring line count of `src/prismatiq.cr`
- **THEN** file contains 300 or fewer lines

### Requirement: Standardized Error Handling
All public API methods SHALL return `Result(T, Error)` types with structured Error objects containing type, message, and context.

**Previous:** Multiple error handling approaches (sentinel values, PaletteResult, exceptions, Result)  
**Updated:** Single standardized approach:
```crystal
# All methods return Result
def get_palette(path : String, options : Options) : Result(Array(RGB), Error)

# Structured error with taxonomy
struct Error
  getter type : ErrorType
  getter message : String
  getter context : Hash(String, String)?
end

enum ErrorType
  FileNotFound
  InvalidImagePath
  UnsupportedFormat
  CorruptedImage
  InvalidOptions
  ProcessingFailed
end
```

#### Scenario: Consistent error return type
- **WHEN** calling any public PrismatIQ method
- **THEN** return type is `Result(T, Error)` where T is the success value type

#### Scenario: No sentinel error values
- **WHEN** error occurs during processing
- **THEN** method returns `Result::Err(Error)`, never array of RGB values

### Requirement: Thread Safety Guarantees
The implementation SHALL provide thread-safe operation through instance-based state and fiber-based concurrency.

**Previous:** Global class variables with ThreadSafeCache, Thread.new for parallelism  
**Updated:** Instance-based caching with ThreadSafeCache, fiber-based parallelism with channels

#### Scenario: No global mutable state
- **WHEN** reviewing Accessibility and Theme modules
- **THEN** no @@ class variables exist, only instance variables

#### Scenario: Fiber-based parallelism
- **WHEN** processing image in parallel
- **THEN** fibers are spawned using `spawn`, not `Thread.new`, and communicate via channels

#### Scenario: Instance isolation
- **WHEN** multiple instances of AccessibilityCalculator exist
- **THEN** cache state in one instance does not affect others

## ADDED Requirements

### Requirement: Secure System Calls
System information retrieval SHALL use native Crystal APIs instead of shell command execution.

#### Scenario: CPU count without shell
- **WHEN** library detects CPU count
- **THEN** implementation uses LibC.sysctl (macOS) or /proc/cpuinfo (Linux), not backtick shell commands

#### Scenario: Platform-specific implementation
- **WHEN** running on different platforms
- **THEN** compile-time flags select appropriate system call implementation

### Requirement: Memory Optimization
Histogram allocation SHALL use lazy initialization and object pooling to reduce memory overhead.

#### Scenario: Lazy histogram allocation
- **WHEN** processing small image (<100K pixels)
- **THEN** only necessary histograms are allocated, not one per thread

#### Scenario: Histogram pooling
- **WHEN** processing multiple chunks
- **THEN** histogram objects are reused from pool instead of repeatedly allocated

#### Scenario: Memory reduction target
- **WHEN** processing typical image workloads
- **THEN** memory usage is reduced by 25-40% compared to previous implementation

### Requirement: Comprehensive Testing
Test coverage SHALL exceed 90% for edge cases and error conditions.

#### Scenario: Edge case coverage
- **WHEN** running test suite
- **THEN** corrupted files, oversized images, invalid parameters, and concurrent access are all tested

#### Scenario: Error path coverage
- **WHEN** running test suite
- **THEN** all error types (FileNotFound, CorruptedImage, etc.) have dedicated test cases

#### Scenario: Concurrent access testing
- **WHEN** running thread safety tests
- **THEN** tests spawn multiple fibers accessing shared resources and verify no race conditions

## REMOVED Requirements

### Requirement: PaletteResult struct
**Reason:** Duplicates standard Result type functionality  
**Migration:** Use `Result(Array(RGB), Error)` instead. Access success value via `.value`, error via `.error`

### Requirement: Deprecated method signatures
**Reason:** Inconsistent API surface with multiple ways to call same method  
**Migration:** Use `get_palette(path, options)` with Options struct instead of positional arguments `get_palette(path, color_count, quality, threads)`

### Requirement: Sentinel error value
**Reason:** Ambiguous return value indistinguishable from legitimate black pixels  
**Migration:** Check for `Result::Err` instead of comparing to `[RGB.new(0, 0, 0)]`

## Unchanged Requirements

The following requirements from the original spec remain unchanged:
- YIQ Color Space Adoption
- 5-Bit Color Quantization
- VBox Structure
- MMCQ Algorithm Details
- Options-based API design
- ICO File Support
- Quality Parameter behavior
- Alpha Filtering
- Constants Centralization
