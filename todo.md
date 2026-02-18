PrismatIQ — Color extraction library TODO (Crystal-only)

Purpose: record work items, risks and recommendations for PrismatIQ — a Crystal-only,
high-performance replacement for ColorThief. This repository is library-first and
must not include frontend/browser code. Quickheadlines migration guidance is provided
in a separate section for future adoption; that guidance should not introduce code
into the PrismatIQ library that couples it to any specific app or JS runtime.

Scope constraints
- Language: Crystal only. All implementation, tests, examples, and CLI tools must be
  Crystal code.
- No frontend/browser code: do not add JS, TypeScript, or browser-specific helpers in
  this repository. Migration guidance for browser usage may be documented but not
  implemented here.

Potential issues (library-focused)
- API stability: design a small, stable public API surface so adopters can rely on it.
- Input formats: support buffers and common image formats (PNG, JPEG, ICO, SVG, WebP).
  Provide robust detection and clear errors for unsupported formats.
- Determinism & tests: ensure deterministic extraction across runs, thread counts, and
  concurrency modes; add tests with bundled sample images.
- Performance: prioritize low-memory, high-throughput implementations. Expose tunable
  sampling and concurrency controls with safe defaults.
- Accessibility helpers: provide contrast_ratio and suggest_text_color helpers (WCAG),
  but keep UI decisions to consumers.
- Error handling: return explicit errors or nils for invalid inputs and avoid panics.

Library recommendations (PrismatIQ deliverables)
1. Core API (Crystal):
   - PrismatIQ.extract_from_buffer(pixels : Array(UInt8), width : Int32, height : Int32) -> Array(Int32)
     (dominant RGB)
   - PrismatIQ.extract_from_file(path : String) -> Tuple(Array(Int32), Hash?) or Result type
   - PrismatIQ.palette_from_buffer / palette_from_file -> Array(Array(Int32)) (ColorThief style)
   - Helpers: rgb_to_hex, contrast_ratio, suggest_text_color(bg_rgb, threshold = 4.5)
2. ColorThief compatibility: provide a CLI example (`examples/color_thief_adapter.cr`) that
   reads an image and outputs ColorThief-compatible JSON/palette arrays so downstream apps
   can migrate with minimal change.
3. Buffer-first: prioritize buffer-based APIs (servers download images into memory and call
   the library). Avoid adding HTTP clients to the library — leave networking to consumers.
4. ICO handling: include dedicated ICO parsing (extract best resolution/icon entry) — Quickheadlines
   feeds use favicons heavily; ICO support is a must.
5. Tests & determinism: deterministic tests, cross-thread determinism checks, and sample
   images embedded in `spec/fixtures`.
6. Performance benchmarks: microbenchmarks demonstrating throughput and memory for typical
   favicon sizes and for larger images.

Implementation tasks (Crystal-only)
1. Implement buffer-based dominant color extraction with configurable sample count and step.
2. Implement ICO support (read multiple images from ICO and pick best candidate by area+opacity).
3. Implement palette extraction (k-means or median-cut, tuned for speed) and a ColorThief-compatible
   export wrapper.
4. Implement WCAG helpers for contrast and text suggestion.
5. Add CLI example `examples/color_thief_adapter.cr` that emits JSON compatible with ColorThief consumers.
6. Add specs under `spec/` with deterministic checks and fixture images.
7. Add benchmarks under `benchmark/` or similar.

Migration guidance (for other projects like Quickheadlines)
- Document how consumers should call PrismatIQ from server code (download favicon into a buffer,
  call extract_from_buffer, persist results to DB). Provide pseudocode examples, not JS code.
- Provide notes on browser migration strategies (e.g., keep existing client-side ColorThief usage,
  or call a server endpoint that uses PrismatIQ) — this is documentation only.

Verification
- Unit/spec tests -> deterministic outputs for fixture images.
- Benchmarks -> show performance improvement vs reference implementation.

Decisions for you
1) Approve implementation of PrismatIQ (Crystal-only) with the deliverables above.
2) Or ask for a detailed design doc/spec only (no implementation) first.

Notes
- This file explicitly forbids adding frontend/browser code to this library. Migration notes
  for other projects may live here but must be implementation-free.
