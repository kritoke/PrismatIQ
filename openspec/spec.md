# Specification: PrismatIQ Technical Requirements

## 1. Color Space: YIQ
- All internal quantization logic must use the YIQ (Luma, In-phase, Quadrature) space.
- Formula: 
  - $Y = 0.299R + 0.587G + 0.114B$
  - $I = 0.596R - 0.274G - 0.322B$
  - $Q = 0.211R - 0.523G + 0.312B$

## 2. Image Processing
- Library: `naqvis/crimage`.
- Input: String path, `IO`, or `CrImage` object.
- Sampling: Must support a `quality` parameter (Int32) to skip every Nth pixel for speed.

## 3. Algorithm: MMCQ (Modified Median Cut)
- Quantization must use VBoxes (Volume Boxes) to partition the color space.
- The box with the highest "Priority" (Population * Volume) is split until the target palette size is reached.

## 4. API Interface
```crystal
palette = PrismatIQ.get_palette("image.jpg", color_count: 5, quality: 10)
dominant = PrismatIQ.get_color("image.jpg")