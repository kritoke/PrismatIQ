# PrismatIQ
A high-performance Crystal shard for extracting dominant color palettes from images using the YIQ color space. This is a port of the Color Thief logic (MMCQ) but optimized for Crystal's performance and perception-based color math.

Getting started
 - Install shards: `shards install`
 - Run tests: `crystal spec`

ColorThief-like example
 - Example CLI that produces a ColorThief-compatible JSON payload is at `examples/color_thief_adapter.cr`.
 - Usage: `crystal run examples/color_thief_adapter.cr -- path/to/image.jpg [count] [quality] [threads]`
   - `count` (optional): number of colors to return (default 5)
   - `quality` (optional): sampling step (default 10). Lower is higher fidelity, higher is faster.
   - `threads` (optional): number of worker threads for histogram build (default 0 = auto)

APIs of interest
 - `PrismatIQ.get_palette_from_buffer(pixels, width, height, color_count = 5, quality = 10, threads = 0)`
   - Returns `Array(PrismatIQ::RGB)` like ColorThief's palette (but as structs).
 - `PrismatIQ.get_palette_with_stats_from_buffer(pixels, width, height, color_count = 5, quality = 10, threads = 0)`
   - Returns `[Array(PrismatIQ::PaletteEntry), Int32]` where `PaletteEntry` has `rgb`, `count`, and `percent`.
 - `PrismatIQ.get_palette_color_thief_from_buffer(...)`
   - Convenience wrapper that returns `Array(String)` of hex colors (dominant first) to match ColorThief consumers.

Environment knobs
 - `PRISMATIQ_THREADS`: override default thread detection
 - `PRISMATIQ_MERGE_CHUNK`: override merge chunk size (for histogram merging)
 - `PRISMATIQ_DEBUG`: enable debug traces

Notes
 - Tests exercise determinism across thread counts and compatibility with ColorThief-like output.
 - The library quantizes into 5 bits per Y/I/Q axis (32³ = 32768 histogram slots).

Example output
 - The adapter emits a small JSON payload. Example (pretty-printed) output:

```json
{
  "colors": ["#e74c3c", "#2ecc71", "#3498db"],
  "entries": [
    { "hex": "#e74c3c", "count": 1200, "percent": 0.6 },
    { "hex": "#2ecc71", "count": 500,  "percent": 0.25 },
    { "hex": "#3498db", "count": 300,  "percent": 0.15 }
  ],
  "total_pixels": 2000
}
```

This format makes it easy to consume the dominant palette (the `colors` array) while
also exposing counts and percentages for richer UI or analytics use-cases.

Version
 - Current library version: `0.1.0` (see `src/prismatiq.cr`)

Changelog
 - See `CHANGELOG.md` for a concise list of unreleased and past changes.

Release notes / maintaining the changelog
 - When preparing a release: bump the `VERSION` constant in `src/prismatiq.cr` and
   add an entry to `CHANGELOG.md` under a new heading for the release (version + date).

CI
 - A GitHub Actions workflow is included at `.github/workflows/ci.yml` that runs specs
   and executes the example against the bundled sample image.

Warning
 - This is an early preview (v0.1.0). The code has automated tests but the library is
   still new and not battle-tested across many image types and platforms. Use at your
   own risk in production workloads; validate results for your dataset and consider
   pinning to a released version.

Additional notes
 - Multithreaded histogram building with per-thread locals and chunked merging to
   improve performance and cache locality on multi-core machines.
 - Adaptive merge chunk sizing that attempts to use CPU L2 cache sizing when available
   (probe via sysctl or sysfs), with an environment override via `PRISMATIQ_MERGE_CHUNK`.
 - Public APIs for buffer-based extraction (suitable for server code that already has
   an image buffer) and helpers to return ColorThief-like hex arrays for easy adoption.
 - Benchmarks and micro-bench scripts are included in the `bench/` folder to help
   tune parameters (merge chunk, thread count, quality) on your target hardware.
 - The MMCQ implementation was adjusted to include deterministic tie-breaking so
   results are stable across different thread counts and runs.

If you rely on this library for production, please open an issue with sample images
that cause problems so we can improve robustness.
