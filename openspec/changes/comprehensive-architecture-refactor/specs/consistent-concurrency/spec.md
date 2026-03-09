## ADDED Requirements

### Requirement: Single consistent concurrency model
The system SHALL use a single, consistent concurrency model across all async operations instead of mixing raw threads, fibers, and channels, to improve maintainability and reduce cognitive load.

#### Scenario: Histogram building uses standardized thread pool
- **WHEN** building histograms with multiple threads
- **THEN** implementation uses a standardized thread pool pattern instead of ad-hoc `Thread.new` calls

#### Scenario: Async operations use standardized fiber pattern
- **WHEN** performing async palette extraction
- **THEN** implementation uses standardized fiber-based concurrency with clear error handling

#### Scenario: No mixed concurrency models exist
- **WHEN** examining the source code for concurrency patterns
- **THEN** only one primary concurrency model is used throughout the codebase

#### Scenario: Concurrency primitives are encapsulated
- **WHEN** examining the source code structure
- **THEN** concurrency primitives are encapsulated in dedicated utility modules

#### Scenario: Thread safety is guaranteed through clear patterns
- **WHEN** shared resources are accessed concurrently
- **THEN** proper synchronization mechanisms are used consistently