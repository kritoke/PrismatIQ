# Delta Spec: PrismatIQ Implementation

**Date:** Feb 7, 2026
**Status:** Implemented (Phases 1-4.1 Complete)
**Author:** OpenSpec Workflow

## Key Design Decisions

### YIQ Color Space Adoption
The implementation uses the YIQ color space for perceptual quantization, following NTSC standards:
- **Y (Luma):** `0.299R + 0.587G + 0.114B` - perceptual brightness
- **I (In-phase):** `0.596R - 0.274G - 0.322B` - orange-blue axis
- **Q (Quadrature):** `0.211R - 0.523G + 0.312B** - purple-green axis

Reverse conversion (YIQ to RGB):
- **R:** `Y + 0.956I + 0.621Q`
- **G:** `Y - 0.272I - 0.647Q`
- **B:** `Y - 1.106I + 1.703Q`

### 5-Bit Color Quantization
To keep histogram memory-efficient, colors are downsampled to 5 bits per channel:
- Y range: 0-255 → 0-31 (32 levels)
- I range: -274 to 274 → 0-31
- Q range: -523 to 523 → 0-31

This creates a 32³ = 32,768 entry histogram (vs 16.7M for 8-bit RGB).

### VBox Structure
Each VBox tracks:
- Boundary coordinates: `y1, y2, i1, i2, q1, q2` (5-bit space)
- Population count: `count`
- Priority: `count * volume` for median-cut decisions

### MMCQ Algorithm Details
1. Build initial VBox from all histogram entries
2. Use max-heap PriorityQueue ordered by priority
3. Iteratively split box with highest priority
4. Split axis = longest dimension (Y, I, or Q)
5. Split point = median of population along axis
6. Continue until target color count reached

### API Design
```crystal
PrismatIQ.get_palette(path, color_count: 5, quality: 10)
PrismatIQ.get_color(path)  # palette of 1
```

Supports String path, IO, or CrImage inputs.

## Performance Considerations

### Quality Parameter
The `quality` parameter controls pixel sampling:
- `quality: 1` = every pixel (slowest)
- `quality: 10` = every 10th pixel (fastest)
- Default = 10

### Alpha Filtering
Pixels with alpha < 125 are skipped to ignore transparent regions.

### Memory
- Histogram: Hash(Int32, Int32) with ~32K max entries
- VBoxes: Array of at most `color_count` entries
- No large arrays copied in pixel loop

## Remaining Work
- **Task 4.2:** Performance optimization (verify no array copies, alpha handling)
- **Task 4.3:** Documentation (README.md with examples and benchmarks)
