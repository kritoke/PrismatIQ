# Clean Break v0.5.0 Release

## Overview
This change prepares PrismatIQ for a clean v0.5.0 release by removing all deprecated APIs and making the v2 Result-based API the standard. This creates a clean, modern codebase without legacy baggage.

## Goals
- Remove all deprecated v1 APIs completely
- Make v2 Result-based APIs the primary interface
- Update all documentation and examples to use only v2 APIs  
- Update version to 0.5.0 across all files
- Ensure comprehensive test coverage for new APIs only
- Create clean migration path for users

## Breaking Changes
- Complete removal of all v1 deprecated methods that used sentinel error values `[RGB.new(0,0,0)]`
- Removal of module-level `Accessibility` and `Theme` methods (now instance-based only)
- Removal of old API signatures with positional parameters
- All APIs now return explicit `Result(Array(RGB), Error)` types

## Non-Breaking Changes  
- Keep existing Options-based API (introduced in v0.4.x) as it's already modern
- Maintain all performance improvements, thread safety, and security fixes already implemented
- Keep backward compatible Options struct usage

## Migration Requirements
Users must update their code to:
1. Use v2 APIs (`get_palette_v2` instead of `get_palette`)
2. Handle `Result` types explicitly instead of checking for sentinel values
3. Create `AccessibilityCalculator` and `ThemeDetector` instances instead of using module methods