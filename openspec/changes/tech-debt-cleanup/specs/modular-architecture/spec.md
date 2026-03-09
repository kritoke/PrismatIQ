# Spec: Modular Architecture

**Capability:** modular-architecture  
**Status:** Proposed  
**Version:** 1.0  

## ADDED Requirements

### Requirement: Main file under 300 lines
The main `src/prismatiq.cr` file SHALL be limited to 300 lines or fewer, containing only public API definitions, configuration, and module requires.

#### Scenario: Main file size check
- **WHEN** measuring line count of `src/prismatiq.cr`
- **THEN** file contains 300 or fewer non-empty, non-comment lines

#### Scenario: Main file contains only API
- **WHEN** reviewing contents of `src/prismatiq.cr`
- **THEN** file contains only `require` statements, module namespace definition, public method signatures, and configuration structs

### Requirement: Algorithm module encapsulates MMCQ
All Modified Median Cut Quantization (MMCQ) algorithm implementation details SHALL be located in `src/prismatiq/algorithm/` directory with clear separation from API and I/O concerns.

#### Scenario: MMCQ algorithm location
- **WHEN** looking for VBox splitting logic
- **THEN** implementation is found in `src/prismatiq/algorithm/mmcq.cr`

#### Scenario: Algorithm module no I/O dependencies
- **WHEN** reviewing algorithm module imports
- **THEN** module does not import or depend on file I/O, image loading, or system call modules

### Requirement: Core module handles data processing
Histogram building, merging, and palette extraction orchestration SHALL be located in `src/prismatiq/core/` with no direct file I/O.

#### Scenario: Histogram building location
- **WHEN** looking for histogram construction logic
- **THEN** implementation is found in `src/prismatiq/core/histogram.cr`

#### Scenario: Core module receives data not files
- **WHEN** core module methods are called
- **THEN** parameters are pixel arrays or histograms, not file paths or IO objects

### Requirement: Utils module handles system interaction
System information retrieval, file loading, and image reading SHALL be located in `src/prismatiq/utils/` providing clean interfaces to algorithm and core modules.

#### Scenario: System info location
- **WHEN** looking for CPU count detection logic
- **THEN** implementation is found in `src/prismatiq/utils/system_info.cr`

#### Scenario: Image reader location
- **WHEN** looking for image file loading logic
- **THEN** implementation is found in `src/prismatiq/utils/image_reader.cr`

### Requirement: Types defined in dedicated module
All data types (RGB, VBox, Options, Error, Result) SHALL be defined in `src/prismatiq/types.cr` to provide a single location for type definitions.

#### Scenario: Type definitions location
- **WHEN** looking for RGB struct definition
- **THEN** definition is found in `src/prismatiq/types.cr`

#### Scenario: Types module has no dependencies
- **WHEN** reviewing types.cr imports
- **THEN** module imports only standard library and has no dependencies on other PrismatIQ modules

### Requirement: Clear module dependency graph
Module dependencies SHALL form a directed acyclic graph with no circular dependencies: utils → types, core → utils + types, algorithm → types, main → all.

#### Scenario: No circular dependencies
- **WHEN** analyzing module import graph
- **THEN** no module transitively imports itself

#### Scenario: Dependency hierarchy respected
- **WHEN** module A imports module B
- **THEN** module B does not import module A directly or transitively

### Requirement: Each module has single responsibility
Each module SHALL have a clear, singular purpose documented in a module-level comment with no overlapping responsibilities between modules.

#### Scenario: Algorithm module responsibility
- **WHEN** reading algorithm module documentation
- **THEN** module description states "Implements Modified Median Cut Quantization algorithm for color palette extraction" and nothing else

#### Scenario: No duplicate implementations
- **WHEN** searching for YIQ conversion functions
- **THEN** only one implementation exists in `src/prismatiq/algorithm/color_space.cr`

### Requirement: Modules testable in isolation
Each module SHALL be testable without requiring the full library, using dependency injection or interfaces where needed.

#### Scenario: Algorithm module standalone test
- **WHEN** writing unit tests for MMCQ algorithm
- **THEN** tests can run by requiring only `src/prismatiq/algorithm/mmcq.cr` and `types.cr`

#### Scenario: Core module mockable dependencies
- **WHEN** testing histogram building
- **THEN** tests can provide mock pixel data without loading actual image files

## MODIFIED Requirements

None - this is a new capability being introduced.

## REMOVED Requirements

### Requirement: Monolithic implementation file
**Reason:** 989-line file violates single responsibility principle and makes navigation/maintenance difficult  
**Migration:** Code has been reorganized into focused modules. Update imports if accessing internal classes directly.
