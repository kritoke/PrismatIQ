# Technical Design: Fix Incomplete Refactor and Thread Safety

## Architecture Overview

This fix addresses critical issues in the PrismatIQ library that prevent it from functioning correctly. The design focuses on:

1. Completing the missing `PaletteConvenience` implementation
2. Ensuring thread safety throughout the codebase
3. Unifying error handling patterns
4. Fixing algorithmic bugs

## Phase 1: PaletteConvenience Implementation

### File: `src/prismatiq/core/palette_convenience.cr`

This class provides convenience methods that wrap the core `PaletteExtractor` functionality with additional features.

```crystal
module PrismatIQ
  module Core
    class PaletteConvenience
      def initialize(@config : Config = Config.default)
      end

      # Async extraction using Crystal channels
      def get_palette_channel(path : String, options : Options) : Channel(Array(RGB))
        ch = Channel(Array(RGB)).new(1)
        spawn do
          begin
            extractor = PaletteExtractor.new(@config)
            palette = extractor.extract_from_path(path, options)
            ch.send(palette)
          rescue
            ch.send([RGB.new(0, 0, 0)])
          ensure
            ch.close
          end
        end
        ch
      end

      # Extract palette with detailed statistics
      def get_palette_with_stats(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options) : Tuple(Array(PaletteEntry), Int32)
        extractor = PaletteExtractor.new(@config)
        
        # Build histogram to get pixel counts
        histo, total_pixels = extractor.build_histo_from_buffer(pixels, width, height, options)
        
        # Get palette colors
        palette = extractor.extract_from_buffer(pixels, width, height, options)
        
        # Build entries with stats
        entries = build_palette_entries(palette, histo, total_pixels)
        
        {entries, total_pixels}
      end

      # ColorThief-compatible hex output
      def get_palette_color_thief(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options) : Array(String)
        palette = PaletteExtractor.new(@config).extract_from_buffer(pixels, width, height, options)
        palette.map(&.to_hex)
      end

      # Single dominant color extraction
      def get_color_from_path(path : String) : RGB
        options = Options.new(color_count: 1)
        palette = PaletteExtractor.new(@config).extract_from_path(path, options)
        palette.first? || RGB.new(0, 0, 0)
      end

      def get_color_from_io(io : IO) : RGB
        options = Options.new(color_count: 1)
        palette = PaletteExtractor.new(@config).extract_from_io(io, options)
        palette.first? || RGB.new(0, 0, 0)
      end

      def get_color(img) : RGB
        options = Options.new(color_count: 1)
        if img.is_a?(CrImage::Image)
          palette = PaletteExtractor.new(@config).extract_from_image(img, options)
          palette.first? || RGB.new(0, 0, 0)
        else
          get_color_from_path(img.to_s)
        end
      end

      private def build_palette_entries(palette : Array(RGB), histo : Array(UInt32), total_pixels : Int32) : Array(PaletteEntry)
        return [] of PaletteEntry if total_pixels == 0

        palette.map do |rgb|
          y, i, q = YIQConverter.quantize_from_rgb(rgb.r, rgb.g, rgb.b)
          idx = YIQConverter.to_index(y, i, q)
          count = histo[idx]?.try(&.to_i) || 0
          percent = count.to_f64 / total_pixels.to_f64
          PaletteEntry.new(rgb, count, percent)
        end
      end
    end
  end
end
```

### Integration Points

The `PaletteConvenience` class:
- Delegates to `PaletteExtractor` for actual extraction
- Adds statistics calculation on top of extracted palettes
- Provides async wrapper using Crystal fibers and channels
- Maintains consistency with the existing `Options` pattern

## Phase 2: Thread Safety Fixes

### File: `src/prismatiq/core/histogram_pool.cr`

Current issues:
- `acquire` method fills histograms without synchronization
- Multiple fibers can access the same histogram simultaneously
- No protection for the `@used` array

Proposed fix:

```crystal
class HistogramPool
  @histograms : Array(Array(UInt32)?)
  @used : Array(Bool)
  @mutex : Mutex

  def initialize(worker_count : Int32)
    @histograms = Array(Array(UInt32)?).new(worker_count) { nil }
    @used = Array(Bool).new(worker_count, false)
    @mutex = Mutex.new
  end

  def acquire(index : Int32) : Array(UInt32)
    @mutex.synchronize do
      if index >= @histograms.size
        raise ArgumentError.new("Index #{index} out of bounds for pool size #{@histograms.size}")
      end

      if @histograms[index].nil?
        @histograms[index] = Array(UInt32).new(Constants::HISTOGRAM_SIZE, 0_u32)
      else
        @histograms[index].as(Array(UInt32)).fill(0_u32)
      end
      @used[index] = true
      @histograms[index].as(Array(UInt32))
    end
  end

  def release(index : Int32) : Nil
    @mutex.synchronize do
      if index < @used.size
        @used[index] = false
      end
    end
  end
  
  # ... rest of methods with mutex protection
end
```

### File: `src/prismatiq/core/palette_extractor.cr`

The parallel processing in `build_histo_from_buffer` needs to ensure:
1. Each fiber gets its own histogram from the pool
2. No two fibers share the same histogram
3. Final merge is properly synchronized

Current code already does #1 and #2 correctly by design (each fiber gets its own index), but we need to verify no race conditions exist in the merge step.

The `merge_histograms` method is called sequentially after all fibers complete, so it's already thread-safe.

## Phase 3: Error Handling Unification

### Strategy

1. **Remove sentinel values**: Replace `[RGB.new(0,0,0)]` returns with proper error propagation
2. **Consistent Result types**: All error-returning methods should use `Result(T, Error)`
3. **Exception hierarchy**: Create specific exception types for different error categories

### Changes to `src/prismatiq.cr`

In the `get_palette(img)` method, replace:

```crystal
# Current (BAD)
rescue ex : Exception
  STDERR.puts "get_palette: CrImage.read failed: #{ex.message}" if Config.default.debug?
  read_img = nil
end
# ... eventually returns [RGB.new(0, 0, 0)]
```

With proper error propagation or at minimum, log and raise with context.

## Phase 4: Algorithmic Fixes

### File: `src/prismatiq/algorithm/color_space.cr`

Fix the YIQ quantization to use correct linear mapping:

```crystal
def self.quantize_from_rgb(r : Int32, g : Int32, b : Int32) : Tuple(Int32, Int32, Int32)
  # Convert to YIQ
  y = (Constants::YIQ::Y_FROM_R * r) + (Constants::YIQ::Y_FROM_G * g) + (Constants::YIQ::Y_FROM_B * b)
  i = (Constants::YIQ::I_FROM_R * r) + (Constants::YIQ::I_FROM_G * g) + (Constants::YIQ::I_FROM_B * b)
  q = (Constants::YIQ::Q_FROM_R * r) + (Constants::YIQ::Q_FROM_G * g) + (Constants::YIQ::Q_FROM_B * b)

  # Y range: [0, 255] -> [0, 31]
  y_q = (y * 31.0 / 255.0).round.to_i.clamp(0, 31)

  # I range: [-0.596, 0.596] (normalized) -> [0, 31]
  # Original I is in range [-152, 152] approximately
  i_normalized = (i + 152.0) / 304.0  # Map to [0, 1]
  i_q = (i_normalized * 31.0).round.to_i.clamp(0, 31)

  # Q range: [-0.523, 0.312] (normalized) -> [0, 31]
  # Original Q is in range [-134, 134] approximately
  q_normalized = (q + 134.0) / 268.0  # Map to [0, 1]
  q_q = (q_normalized * 31.0).round.to_i.clamp(0, 31)

  {y_q, i_q, q_q}
end
```

### File: `src/prismatiq/types.cr`

Optimize `VBox` by caching counts during construction rather than recalculating:

```crystal
struct VBox
  # Add cached pixel data for faster operations
  @pixel_indices : Array(Int32)?

  def split : Tuple(VBox, VBox)
    axis = find_split_axis
    return {self, VBox.new(0, 0, 0, 0, 0, 0)} if axis == -1

    # Pre-compute indices only once
    indices = get_indices(axis)
    indices.sort!

    mid = indices.size // 2
    return {self, VBox.new(0, 0, 0, 0, 0, 0)} if mid == 0

    split_at = indices[mid - 1]

    # ... rest of method
  end
end
```

## Phase 5: Testing Strategy

### Thread Safety Tests

Create `spec/thread_safety_spec.cr`:

```crystal
describe "Thread Safety" do
  it "handles concurrent histogram pool access" do
    pool = HistogramPool.new(4)
    
    channel = Channel(Array(UInt32)).new(4)
    
    4.times do |i|
      spawn do
        histo = pool.acquire(i)
        histo[0] = i.to_u32
        sleep 10.milliseconds  # Force contention
        channel.send(histo)
      end
    end
    
    4.times do
      histo = channel.receive
      # Each histogram should have been modified independently
    end
  end
  
  it "produces consistent results with parallel processing" do
    # Create a test image
    pixels = create_test_image(1000, 1000)
    options = Options.new(threads: 4)
    
    results = 10.times.map do
      PrismatIQ.get_palette(pixels, 1000, 1000, options)
    end.to_a
    
    # All results should be identical
    results.uniq.size.should eq(1)
  end
end
```

### Regression Tests

Ensure all existing tests in:
- `spec/palette_stats_spec.cr`
- `spec/prismatiq_spec.cr`
- `spec/features_spec.cr`
- All other spec files

Continue to pass after changes.

## Implementation Order

1. Create `palette_convenience.cr` (unblocks compilation)
2. Fix thread safety in `histogram_pool.cr`
3. Fix YIQ quantization
4. Optimize VBox operations
5. Unify error handling
6. Run full test suite
7. Add thread safety tests
8. Performance verification

## Rollback Plan

Since this is on a feature branch:
- All changes are isolated
- Can easily reset or delete branch if issues arise
- No impact on main branch until merged

## Verification Checklist

- [ ] Code compiles without errors
- [ ] All existing tests pass
- [ ] New thread safety tests pass
- [ ] No compiler warnings
- [ ] Performance benchmarks show no regression
- [ ] Memory usage is acceptable
- [ ] Documentation is updated
