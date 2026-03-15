## Why

PrismatIQ currently has superior color extraction, theme detection, and accessibility calculation capabilities compared to the quickheadlines color_extractor library. However, it lacks a concise, user-friendly API that matches the expected interface for quickheadlines integration. This change will provide a clean, generic theme extraction API that enables quickheadlines to use PrismatIQ as a drop-in replacement while maintaining PrismatIQ's independence as a standalone theming library.

## What Changes

- Add `extract_theme(source, options)` method supporting file paths, URLs, and buffers
- Add `fix_theme(json, options)` method for accessibility compliance auto-correction  
- Implement URL support using Crystal's built-in HTTP::Client (no external dependencies)
- Create `ThemeResult` struct with JSON serialization matching quickheadlines format
- Integrate with existing ThreadSafeCache for 7-day caching
- Maintain all existing buffer-based extraction and ICO handling functionality

## Capabilities

### New Capabilities
- `theme-extraction`: Provides unified theme extraction from multiple sources (files, URLs, buffers) with accessibility-compliant text color generation
- `theme-correction`: Auto-corrects existing theme configurations to meet WCAG accessibility standards

### Modified Capabilities

## Impact

- New public API methods in main PrismatIQ module
- HTTP support added via Crystal's built-in HTTP::Client
- Existing ColorExtractor, ThemeDetector, and AccessibilityCalculator remain unchanged
- Backward compatibility maintained for all existing functionality
- No new external dependencies required