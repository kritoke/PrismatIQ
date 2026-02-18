# Proposal: PrismatIQ Color Extraction Shard

## Summary
Build a high-performance Crystal shard for extracting dominant color palettes from images using the YIQ color space. This is a port of the Color Thief logic (MMCQ) but optimized for Crystal's performance and perception-based color math.

## Motivation
Existing color extraction tools in Crystal are either thin wrappers around C libraries or lack the perceptual accuracy provided by the YIQ color space. PrismatIQ will be the "de facto" pure-Crystal solution for developers building dynamic UI themes or image analysis tools.

## Success Criteria
- Extract a 5-color palette from a 1080p image in < 100ms.
- Pure Crystal implementation using `naqvis/crimage`.
- High perceptual accuracy by using YIQ-weighted quantization.