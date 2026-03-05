## MODIFIED Requirements

### Requirement: Theme module uses generic thread-safe cache  
The Theme module SHALL replace manual mutex and hash caching with ThreadSafeCache for better code reuse and maintainability.

#### Scenario: Theme detection caching maintains functionality
- **WHEN** Theme.detect_theme is called with background RGB(200, 200, 200)  
- **THEN** method returns :light theme type and caches result for subsequent calls

#### Scenario: Theme analysis maintains functionality
- **WHEN** Theme.analyze_theme is called with background RGB(50, 50, 50)
- **THEN** method returns ThemeInfo with correct luminance (~0.2), perceived brightness, and :dark theme type

#### Scenario: Text palette suggestion maintains functionality
- **WHEN** Theme.suggest_text_palette is called with light background
- **THEN** method returns TextColorPalette with appropriate primary, secondary, and accent colors that meet WCAG compliance

#### Scenario: Cache clearing works correctly
- **WHEN** Theme.clear_cache is called
- **THEN** all cached theme detection results are removed and subsequent calls recompute values