# Spec: Thread Safety

**Capability:** thread-safety  
**Status:** Proposed  
**Version:** 1.0  

## ADDED Requirements

### Requirement: No global mutable class variables
The library SHALL NOT use global mutable class variables (@@variable) that are shared across instances and threads.

#### Scenario: Accessibility module instance-based
- **WHEN** reviewing Accessibility module implementation
- **THEN** no @@luminance_cache or similar class variables exist, only instance variables

#### Scenario: Theme module instance-based
- **WHEN** reviewing Theme module implementation
- **THEN** no @@theme_cache or similar class variables exist, only instance variables

### Requirement: Instance-based caching
Caching SHALL be implemented at the instance level using instance variables, ensuring each instance has isolated cache state.

#### Scenario: Multiple independent instances
- **WHEN** user creates two AccessibilityCalculator instances
- **THEN** cache state in instance A does not affect or share with instance B

#### Scenario: Instance thread safety
- **WHEN** multiple threads access same AccessibilityCalculator instance
- **THEN** ThreadSafeCache ensures safe concurrent access without race conditions

### Requirement: Fiber-based concurrency
Parallel processing SHALL use Crystal fibers and channels instead of raw Thread.new for improved resource efficiency and idiomatic Crystal code.

#### Scenario: Fiber spawn for parallel work
- **WHEN** processing image in parallel
- **THEN** each chunk is processed in a fiber using spawn, not Thread.new

#### Scenario: Channel-based communication
- **WHEN** parallel workers complete histogram building
- **THEN** results are communicated via Channel, not shared mutable state

### Requirement: No shared mutable state between fibers
Fibers SHALL NOT share mutable state directly. All communication MUST use channels or thread-safe data structures.

#### Scenario: Histogram per fiber
- **WHEN** fiber processes image chunk
- **THEN** fiber owns its histogram exclusively until sent via channel

#### Scenario: No mutex for histogram access
- **WHEN** reviewing parallel processing code
- **THEN** no mutex or lock patterns exist for histogram access, only channel sends

### Requirement: ThreadSafeCache for concurrent access
When caching must be shared across threads/fibers, implementations SHALL use the ThreadSafeCache class with double-checked locking pattern.

#### Scenario: Cache safe under concurrent load
- **WHEN** 100 fibers concurrently access same cache key
- **THEN** computation occurs exactly once, all fibers receive same cached value

#### Scenario: Cache performance under load
- **WHEN** cache is accessed from multiple fibers simultaneously
- **THEN** read operations complete without blocking (after initial write)

### Requirement: Convenience singleton for simple cases
Modules SHALL provide a default singleton instance for simple use cases while encouraging instance creation for thread-safe scenarios.

#### Scenario: Module-level convenience method
- **WHEN** user calls `Accessibility.luminance(color)` without creating instance
- **THEN** method delegates to internal singleton instance

#### Scenario: Singleton documented for single-threaded
- **WHEN** reading module documentation
- **THEN** docs clarify singleton is safe for single-threaded use, instances recommended for multi-threaded

#### Scenario: Instance creation documented
- **WHEN** reading module documentation
- **THEN** docs provide example of creating instance for thread-safe usage

### Requirement: No race conditions in tests
Test suite SHALL include concurrent access tests that verify thread safety under load.

#### Scenario: Concurrent cache access test
- **WHEN** test spawns 100 fibers accessing same cache
- **THEN** test passes without data races or inconsistencies

#### Scenario: Concurrent palette extraction test
- **WHEN** test extracts palettes from multiple images concurrently
- **THEN** all extractions complete successfully without interference

### Requirement: Clear thread safety documentation
Public API documentation SHALL clearly indicate thread safety guarantees for each class and method.

#### Scenario: Thread safety in class docs
- **WHEN** reading AccessibilityCalculator class documentation
- **THEN** docs state "Thread-safe: Instance methods can be called concurrently from multiple fibers"

#### Scenario: Singleton limitations documented
- **WHEN** reading module-level method documentation
- **THEN** docs state "Not thread-safe across instances: Use instance methods for concurrent access"

## REMOVED Requirements

### Requirement: Global class variables for caching
**Reason:** Shared mutable global state creates race conditions in multi-threaded environments  
**Migration:** Create instance of AccessibilityCalculator/ThemeDetector for thread-safe usage, or use module-level methods only in single-threaded contexts.

### Requirement: Thread.new for parallel processing
**Reason:** Raw threads are heavier weight than fibers and less idiomatic in Crystal ecosystem  
**Migration:** Internal change only, no user-visible API changes. Parallelism still works, just using fibers instead.
