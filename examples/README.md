Color Thief‑style adapter example
--------------------------------

This folder contains a small CLI adapter that demonstrates how to call
PrismatIQ and emit a ColorThief-compatible JSON payload from a local image.

Script
- `examples/color_thief_adapter.cr` — reads an image file and prints JSON with:
  - `colors`: array of hex strings (dominant first)
  - `entries`: array of objects { hex, count, percent }
  - `total_pixels`: integer

Quick usage
- Run the adapter with Crystal:

  crystal run examples/color_thief_adapter.cr -- path/to/image.jpg

  Optional positional args:
  - `count` (default `5`): how many colors to return
  - `quality` (default `10`): sampling step (lower = higher fidelity)
  - `threads` (default `0`): number of worker threads (0 = auto)

Capture example output
- Example command and saving output to `out.json`:

  crystal run examples/color_thief_adapter.cr -- bench/test_1080p.jpg 5 10 0 > out.json

  Then view the result (pretty-print with any JSON tool). Example content:

  {
    "colors": ["#e74c3c", "#2ecc71", "#3498db"],
    "entries": [
      { "hex": "#e74c3c", "count": 1200, "percent": 0.6 },
      { "hex": "#2ecc71", "count": 500,  "percent": 0.25 },
      { "hex": "#3498db", "count": 300,  "percent": 0.15 }
    ],
    "total_pixels": 2000
  }

Notes
- Use environment knobs to tune behavior:
  - `PRISMATIQ_THREADS` — override default thread detection
  - `PRISMATIQ_MERGE_CHUNK` — override merge chunk size used when aggregating histograms
  - `PRISMATIQ_DEBUG` — enable debug traces to stderr

This example is intentionally small and meant to be copied into server codepaths
that already have an image buffer (pass `img.pix`, `img.width`, `img.height` to
`PrismatIQ.get_palette_with_stats_from_buffer`).
