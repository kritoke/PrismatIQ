# Specification: Thread Safety Requirements

## Overview

This document specifies the thread safety requirements for PrismatIQ, particularly focusing on the histogram pool and parallel processing components.

## Thread Safety Guarantees

### Public API Level

All public methods in the `PrismatIQ` module are guaranteed to be thread-safe and can be called concurrently from multiple fibers without race conditions.

**Examples of safe concurrent usage:**
```crystal
# Multiple concurrent extractions
10.times do
  spawn do
    palette = PrismatIQ.get_palette("image.jpg", options)
    # Safe - no shared state
  end
end

# Concurrent different operations
spawn { PrismatIQ.get_palette("img1.jpg", options) }
spawn { PrismatIQ.get_color("img2.jpg") }
spawn { PrismatIQ.get_palette_with_stats(pixels, w, h, options) }
```

### Internal Components

#### HistogramPool

**Requirements:**
1. Multiple fibers must be able to `acquire` different histograms concurrently
2. A single histogram must never be acquired by more than one fiber at a time
3. The `release` operation must be atomic
4. The `clear` operation must wait for all in-use histograms to be released
5. Statistics queries (`size`, `stats`) must return consistent snapshots

**Implementation Requirements:**
- All mutable operations must be protected by mutex
- No deadlock conditions should be possible
- Performance impact of synchronization should be minimal (<5% overhead)

**Test Requirements:**
```crystal
it "prevents concurrent acquisition of same histogram" do
  pool = HistogramPool.new(4)
  
  # Two fibers try to acquire same index
  # Only one should succeed at a time
  # This should be prevented by the implementation
end

it "allows concurrent acquisition of different histograms" do
  pool = HistogramPool.new(4)
  
  results = Channel(Array(UInt32)).new(4)
  
  4.times do |i|
    spawn do
      histo = pool.acquire(i)
      histo[0] = i.to_u32
      sleep 10.milliseconds  # Force overlap
      results.send(histo)
    end
  end
  
  # All should complete successfully
  4.times { results.receive }
end
```

#### PaletteExtractor

**Requirements:**
1. Each instance maintains no shared mutable state
2. Parallel histogram building uses separate histograms per fiber
3. Final merge is done sequentially after all fibers complete
4. Multiple instances can be used concurrently without coordination

**Current Implementation Status:**
- ✅ Each fiber gets its own histogram index
- ✅ Merge happens after all fibers complete (sequential)
- ⚠️ HistogramPool lacks proper synchronization (being fixed)

**Test Requirements:**
```crystal
it "produces deterministic results regardless of thread count" do
  pixels = create_large_test_image(1000, 1000)
  
  results = [] of Array(RGB)
  
  [1, 2, 4, 8].each do |thread_count|
    options = Options.new(threads: thread_count)
    result = PrismatIQ.get_palette(pixels, 1000, 1000, options)
    results << result
  end
  
  # All results should be identical
  results.uniq.size.should eq(1)
end

it "handles concurrent extractions safely" do
  images = [img1, img2, img3, img4]
  channel = Channel(Array(RGB)).new(4)
  
  images.each do |img|
    spawn do
      palette = PrismatIQ.get_palette(img, options)
      channel.send(palette)
    end
  end
  
  # All should complete without errors or races
  4.times { channel.receive }
end
```

#### AccessibilityCalculator

**Requirements:**
1. Luminance and contrast caches must be thread-safe
2. Cache misses should not result in duplicate computations
3. Cache reads should not block (use read-write lock or similar)

**Current Implementation Status:**
- ✅ Uses `ThreadSafeCache` with mutex protection
- ⚠️ Potential for duplicate computation on cache miss (minor issue)

**Test Requirements:**
```crystal
it "caches luminance calculations safely" do
  calc = AccessibilityCalculator.new
  rgb = RGB.new(128, 128, 128)
  
  results = Channel(Float64).new(10)
  
  10.times do
    spawn do
      lum = calc.relative_luminance(rgb)
      results.send(lum)
    end
  end
  
  # All results should be identical (from cache or computed once)
  lums = 10.times.map { results.receive }.to_a
  lums.uniq.size.should eq(1)
end
```

## Concurrency Model

### Fiber-Based

PrismatIQ uses Crystal's fiber-based concurrency, not OS threads:
- Multiple fibers may run on the same OS thread
- Preemptive scheduling means fibers can be interrupted at any point
- Shared state must still be protected despite being single-threaded

### Spawn and Channels

The library uses `spawn` for parallel work and `Channel` for communication:
- Workers are spawned as separate fibers
- Results are communicated via channels
- Channel operations are inherently thread-safe

### Mutex Usage

When mutex is needed:
- Use `Mutex.new` (not recursive mutex)
- Keep critical sections as small as possible
- Never call user code while holding a mutex
- Use `@mutex.synchronize { }` pattern

## Performance Requirements

Thread safety mechanisms should have minimal performance impact:
- Mutex contention on HistogramPool: <5% overhead in typical usage
- No mutex in hot path of pixel processing
- Cache synchronization: <10% overhead

## Testing Strategy

### Unit Tests
- Test each component in isolation
- Test with simulated concurrency using multiple fibers
- Test edge cases (empty pool, full pool, errors)

### Integration Tests
- Test concurrent extraction operations
- Test with different thread counts
- Test with various image sizes

### Stress Tests
- Run 100+ concurrent extractions
- Run for extended periods checking for memory leaks
- Test with random delays to increase chance of race conditions

### Regression Tests
- Ensure existing tests continue to pass
- Add new tests for any discovered issues
- Run thread sanitizer if available

## Known Issues

### Current Issues (Being Fixed)

1. **HistogramPool synchronization** - lacks mutex protection
2. **Sentinel error values** - can mask real errors in concurrent scenarios
3. **Potential duplicate computation** - in cache implementations

### Future Improvements

1. **Read-write locks** - for cache read-heavy workloads
2. **Lock-free algorithms** - for histogram pool if beneficial
3. **Better error propagation** - to avoid silent failures

## Verification Checklist

Before marking thread safety as complete:
- [ ] All HistogramPool operations protected by mutex
- [ ] No shared mutable state in PaletteExtractor instances
- [ ] Thread safety tests pass consistently (100 runs)
- [ ] Stress tests pass without crashes or hangs
- [ ] No data races detected (manual code review)
- [ ] Performance impact is acceptable (<10% overhead)
- [ ] Documentation updated with thread safety guarantees
