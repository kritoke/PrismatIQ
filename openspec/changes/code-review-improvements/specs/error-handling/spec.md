## ADDED Requirements

### Requirement: All public palette extraction methods SHALL return Result types
All public API methods that extract color palettes from images SHALL return `Result(Array(RGB), PrismatIQ::Error)` to provide explicit error information to callers.

#### Scenario: Successful palette extraction returns ok result
- **WHEN** `get_palette_v2(path, options)` is called with valid image path
- **THEN** returns `Result(Array(RGB), PrismatIQ::Error)` with ok status containing Array(RGB)

#### Scenario: Invalid file path returns error result
- **WHEN** `get_palette_v2(path, options)` is called with non-existent file
- **THEN** returns `Result(Array(RGB), PrismatIQ::Error)` with err status containing FileNotFound error

#### Scenario: Corrupted image returns error result
- **WHEN** `get_palette_v2(path, options)` is called with corrupted image file
- **THEN** returns `Result(Array(RGB), PrismatIQ::Error)` with err status containing CorruptedImage error

### Requirement: Legacy methods SHALL be deprecated with clear migration path
Legacy methods that return sentinel values SHALL be marked with `@[Deprecated]` attribute and include migration instructions.

#### Scenario: Deprecated method shows warning
- **WHEN** deprecated method `get_palette_from_ico(path, color_count, quality, threads)` is called
- **THEN** compiler shows deprecation warning with migration guidance

### Requirement: Error types SHALL include context information
All error types SHALL include relevant context (file path, field name, invalid value) to help debugging.

#### Scenario: InvalidOptions error includes field context
- **WHEN** `Error.invalid_options("color_count", "-5", "must be >= 1")` is created
- **THEN** error message includes "Invalid color_count: must be >= 1" and context includes field="color_count" value="-5"
