# Changelog

All notable changes to this project will be documented in this file.

## v0.2.0 - 2026-02-16

- Add public API: `get_palette_with_stats_from_buffer` returning counts and percentages.
- Add compatibility wrapper `get_palette_color_thief_from_buffer` returning hex strings.
- Add example CLI `examples/color_thief_adapter.cr` and `examples/README.md` demonstrating ColorThief-compatible output.
- Add deterministic priority tie-breaking in MMCQ to ensure stable palettes across thread counts.
- Add tests exercising the new APIs and verifying determinism.
- Add GitHub Actions CI workflow that runs specs and executes the example against a sample image.

## Unreleased

## v0.1.0 - Initial release

- Initial public release of PrismatIQ (v0.1.0). Includes:
  - Core MMCQ implementation on YIQ color space with 5-bit quantization per axis.
  - Buffer-based extraction APIs and ColorThief-compatible helpers.
  - Multithreaded histogram building with adaptive chunked merging.
  - Tests, example adapter, and CI workflow.
