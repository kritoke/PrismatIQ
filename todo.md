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
- Security: predictable temp-files and non-atomic writes in ICO parsing (see `src/prismatiq/ico.cr`) — risk of TOCTOU and symlink attacks.
- Resource exhaustion: reading large files into memory and allocating buffers from unvalidated sizes can cause OOM/DoS.
- Error swallowing: many `rescue nil` / empty rescues around I/O hide failures and return default black palettes; prefer explicit errors.
- Duplicate definitions: `src/vbox.cr` duplicates `PrismatIQ::Color`/`VBox` found in `src/prismatiq.cr` — remove/merge to avoid redefinition/confusion.
- Type/offset safety: file offsets use 32-bit ints in places that should use 64-bit where files may be large.

Other library concerns (stability/style)
- API stability: design a small, stable public API surface so adopters can rely on it.
- Determinism & tests: ensure deterministic extraction across runs, thread counts, and concurrency modes; add tests with bundled sample images.
- Performance: prioritize low-memory, high-throughput implementations. Expose tunable sampling and concurrency controls with safe defaults.
- Accessibility helpers: provide contrast_ratio and suggest_text_color helpers (WCAG), but keep UI decisions to consumers.
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
1. Fix ICO temp-file handling to use `Tempfile`/atomic creation and ensure cleanup in ensure blocks.
2. Add a configurable max file size guard and validate ICO/image entry sizes before allocating large buffers.
3. Replace `rescue nil` around `CrImage.read` / `File.read` with explicit error returns or logging.
4. Remove or merge `src/vbox.cr` to avoid duplicate `Color`/`VBox` definitions.
5. Use Int64 for file offsets/length calculations when parsing file headers.
6. Replace per-byte loops copying pixel buffers with bulk copy methods where available.
7. Add tests for malformed and oversize ICO inputs.

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
