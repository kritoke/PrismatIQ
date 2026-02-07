# Design: Optimization & Documentation

## Performance Optimization (Task 4.2)

### Review Points
1. **Array Copies:** Verify `Slice(UInt8)` from crimage is used directly without copying
2. **Alpha Handling:** Confirm pixels with alpha < 125 are correctly filtered
3. **Memory:** Histogram uses `Hash(Int32, Int32)` - verify no memory leaks

### Profiling Approach
```crystal
# Benchmark code to add
require "benchmark"

Benchmark.ips do |x|
  x.report("1080p palette") { PrismatIQ.get_palette("test.jpg", color_count: 5) }
end
```

## Documentation (Task 4.3)

### README Structure
```markdown
# PrismatIQ

High-performance Crystal color palette extraction.

## Usage

```crystal
require "prismatiq"

palette = PrismatIQ.get_palette("image.jpg", color_count: 5, quality: 10)
```

## API

- `PrismatIQ.get_palette(path, color_count: 5, quality: 10)`
- `PrismatIQ.get_color(path)`

## Performance

Benchmarks on 1080p images: <100ms
```
