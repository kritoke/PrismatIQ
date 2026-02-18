# Design: Internal Architecture

## Data Structures
- `PrismatIQ::Color`: A `struct` containing `y, i, q` as `Float64`.
- `PrismatIQ::VBox`: A `struct` representing a range in the 3D YIQ space. Includes methods for `volume`, `count` (population), and `average_color`.

## Process Flow
1. **Decode**: Load image via `CrImage`.
2. **Sample**: Iterate through `img.pix` using `quality` step. Filter pixels where `Alpha < 125`.
3. **Histogram**: Build a 1D histogram of color occurrences (downsampled to 5-bit for memory efficiency).
4. **Quantize**: 
   - Initialize one `VBox` containing all sampled colors.
   - Use a `PriorityQueue` to manage VBoxes.
   - Iteratively split the most "valuable" VBox until target count is hit.
5. **Output**: Convert the average color of each final VBox back to RGB or Hex.