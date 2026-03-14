## ADDED Requirements

### Requirement: Histogram building SHALL use inline hints for hot loops
The `process_pixel_range` method SHALL use `@[AlwaysInline]` annotation to encourage compiler inlining of the inner pixel processing loop.

#### Scenario: Quality parameter affects step size
- **WHEN** `extract_from_buffer` is called with quality=10
- **THEN** pixel processing samples every 10th pixel (step=10)

#### Scenario: Quality parameter minimum is 1
- **WHEN** `extract_from_buffer` is called with quality=1
- **THEN** pixel processing samples every pixel (step=1)

### Requirement: Parallel processing SHALL use optimal thread count
Histogram building SHALL adapt thread count based on image size for optimal performance.

#### Scenario: Small images use single-threaded processing
- **WHEN** image size < 100,000 pixels
- **THEN** parallel processing is disabled (threads=1)

#### Scenario: Large images use multi-threaded processing
- **WHEN** image size > 2,000,000 pixels
- **THEN** up to 8 threads are used (or configured max)

### Requirement: Alpha threshold SHALL filter transparent pixels
Pixels with alpha below the configured threshold SHALL be excluded from histogram calculations.

#### Scenario: Default alpha threshold excludes transparent pixels
- **WHEN** alpha_threshold = 125 (default)
- **THEN** pixels with alpha < 125 are not included in histogram

#### Scenario: Alpha threshold 0 includes all pixels
- **WHEN** alpha_threshold = 0
- **THEN** all pixels are included regardless of alpha value
