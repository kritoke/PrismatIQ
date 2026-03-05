## ADDED Requirements

### Requirement: Parallel histogram processing uses chunked merging
The system SHALL use chunked histogram merging for improved cache locality when combining results from multiple threads.

#### Scenario: Single-threaded histogram building works correctly
- **WHEN** build_histo_from_buffer is called with threads <= 1
- **THEN** method processes all pixels in single thread and returns correct histogram and pixel count

#### Scenario: Multi-threaded histogram building works correctly
- **WHEN** build_histo_from_buffer is called with threads > 1
- **THEN** method distributes pixel processing across multiple threads and merges results correctly

#### Scenario: Chunked merging improves cache performance
- **WHEN** merge_locals_chunked processes multiple local histograms
- **THEN** method processes histograms in cache-friendly chunks based on L2 cache size or configuration

## MODIFIED Requirements

### Requirement: Histogram building logic is encapsulated in helper methods
The PrismatIQ core module SHALL encapsulate complex histogram building logic in private helper methods to improve readability.

#### Scenario: Pixel range processing is extracted to helper method
- **WHEN** build_histo_from_buffer needs to process a range of pixels
- **THEN** method delegates to process_pixel_range helper with clear parameters

#### Scenario: Histogram merging is extracted to helper method  
- **WHEN** build_histo_from_buffer needs to merge local histograms from multiple threads
- **THEN** method delegates to merge_locals_chunked helper with cache optimization