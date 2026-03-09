# Spec: Memory Optimization

**Capability:** memory-optimization  
**Status:** Proposed  
**Version:** 1.0  

## ADDED Requirements

### Requirement: Lazy histogram allocation
Histograms SHALL be allocated only when first pixel is added, not pre-allocated for each thread regardless of usage.

#### Scenario: Small image single histogram
- **WHEN** processing image smaller than 100,000 pixels with quality > 5
- **THEN** only 1 histogram is allocated instead of thread_count histograms

#### Scenario: Large image parallel allocation
- **WHEN** processing image larger than 1,000,000 pixels
- **THEN** histograms are allocated per thread as needed for parallel processing

### Requirement: Histogram object pooling
The library SHALL maintain a pool of reusable histogram objects to reduce allocation overhead and garbage collection pressure.

#### Scenario: Histogram reuse across chunks
- **WHEN** processing multiple chunks of same image
- **THEN** histogram objects are acquired from pool, used, cleared, and returned to pool

#### Scenario: Pool growth limit
- **WHEN** pool is empty and new histogram needed
- **THEN** new histogram is created and added to pool, pool size limited to 2x thread count

### Requirement: In-place histogram merging
Histogram merging SHALL operate in-place on existing histograms without creating intermediate copies.

#### Scenario: Merge without copy
- **WHEN** merging two histograms during parallel processing
- **THEN** destination histogram is mutated directly, source is cleared and returned to pool

#### Scenario: Memory usage reduction
- **WHEN** processing 5MP image with 16 threads
- **THEN** peak memory usage is at most 600KB (16 histograms + pool) instead of 1MB (32 histograms)

### Requirement: Adaptive chunk sizing
Chunk sizes SHALL be determined dynamically based on image size to balance parallelism benefits with allocation overhead.

#### Scenario: Small image single chunk
- **WHEN** processing image smaller than 50,000 pixels
- **THEN** single chunk is used regardless of thread count to avoid allocation overhead

#### Scenario: Large image optimal chunks
- **WHEN** processing image larger than 5,000,000 pixels
- **THEN** chunk size is calculated to produce 1-2 chunks per CPU core for optimal parallelism

### Requirement: No histogram pre-allocation
The library SHALL NOT pre-allocate fixed-size histograms before knowing actual processing requirements.

#### Scenario: Old behavior eliminated
- **WHEN** reviewing histogram initialization code
- **THEN** no `Array(UInt32).new(32768, 0_u32)` pre-allocation patterns exist before pixel processing

#### Scenario: Allocation on demand
- **WHEN** histogram building begins
- **THEN** histograms are created only when pixels are actually processed

### Requirement: Clear memory ownership
Memory ownership SHALL be explicit with clear lifecycle: pool owns histograms, worker borrows and returns, merger consumes.

#### Scenario: Pool ownership documented
- **WHEN** reading HistogramPool class documentation
- **THEN** ownership semantics are clearly stated in class and method comments

#### Scenario: No leaked histograms
- **WHEN** processing completes or fails
- **THEN** all histograms are returned to pool or garbage collected, none orphaned

### Requirement: Memory usage metrics
The library SHALL log memory allocation statistics when debug logging is enabled to validate optimization effectiveness.

#### Scenario: Debug logging shows allocations
- **WHEN** debug logging is enabled via environment variable
- **THEN** log includes histogram pool size, allocations, and peak usage

#### Scenario: Production no overhead
- **WHEN** debug logging is disabled (default)
- **THEN** no memory tracking overhead occurs

### Requirement: No memory regression
Memory optimization changes SHALL NOT increase memory usage for any workload by more than 5%.

#### Scenario: Small image memory comparison
- **WHEN** processing 100KB image with optimized implementation
- **THEN** memory usage is equal to or less than previous implementation

#### Scenario: Large image memory comparison
- **WHEN** processing 10MB image with optimized implementation
- **THEN** memory usage is at least 25% less than previous implementation

## MODIFIED Requirements

None - this is a new capability being introduced.

## REMOVED Requirements

### Requirement: Fixed 32KB histogram per thread
**Reason:** Pre-allocating full histogram for each thread wastes memory for small images and doesn't scale well  
**Migration:** Internal change only, no user-visible API changes. Memory usage will improve automatically.
