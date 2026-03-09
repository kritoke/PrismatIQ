## ADDED Requirements

### Requirement: Split monolithic codebase into focused modules
The system SHALL be organized into logical, focused modules with clear responsibilities instead of a single monolithic file, following Crystal best practices for maintainability and testability.

#### Scenario: Core algorithm logic is in dedicated module
- **WHEN** examining the source code structure
- **THEN** MMCQ implementation and priority queue are in `src/prismatiq/core/algorithm.cr`

#### Scenario: Histogram building logic is in dedicated module
- **WHEN** examining the source code structure  
- **THEN** histogram building and merging logic are in `src/prismatiq/core/histogram.cr`

#### Scenario: Public API methods are in dedicated module
- **WHEN** examining the source code structure
- **THEN** public API methods are in `src/prismatiq/api/palette_extraction.cr`

#### Scenario: Error handling definitions are in dedicated module
- **WHEN** examining the source code structure
- **THEN** Result type definitions and helpers are in `src/prismatiq/api/error_handling.cr`

#### Scenario: YIQ conversion logic is in dedicated module
- **WHEN** examining the source code structure
- **THEN** centralized YIQ conversion logic is in `src/prismatiq/utils/yiq_converter.cr`

#### Scenario: CPU detection logic is in dedicated module
- **WHEN** examining the source code structure
- **THEN** secure CPU detection without shell commands is in `src/prismatiq/utils/cpu_detection.cr`

#### Scenario: Generic caching implementation is in dedicated module
- **WHEN** examining the source code structure
- **THEN** generic `ThreadSafeCache` implementation is in `src/prismatiq/utils/caching.cr`

#### Scenario: ICO parsing logic is in dedicated module
- **WHEN** examining the source code structure
- **THEN** ICO file parsing with proper validation is in `src/prismatiq/parsers/ico_parser.cr`

#### Scenario: BMP parsing logic is in dedicated module
- **WHEN** examining the source code structure
- **THEN** BMP/DIB format parsing is in `src/prismatiq/parsers/bmp_parser.cr`