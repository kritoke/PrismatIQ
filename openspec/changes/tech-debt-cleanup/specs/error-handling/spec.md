# Spec: Error Handling

**Capability:** error-handling  
**Status:** Proposed  
**Version:** 1.0  

## ADDED Requirements

### Requirement: All public API methods return Result types
All public methods in the PrismatIQ API SHALL return `Result(T, E)` types where T is the success type and E is an Error struct. This requirement ensures consistent error handling across the entire API surface.

#### Scenario: Successful palette extraction returns Ok
- **WHEN** user calls `PrismatIQ.get_palette("valid_image.png", options)` with a valid image
- **THEN** method returns `Result::Ok(Array(RGB))` containing the color palette

#### Scenario: File not found returns Err
- **WHEN** user calls `PrismatIQ.get_palette("nonexistent.png", options)` with a non-existent file
- **THEN** method returns `Result::Err(Error)` with `ErrorType::FileNotFound`

#### Scenario: Invalid image format returns Err
- **WHEN** user calls `PrismatIQ.get_palette("corrupt.png", options)` with a corrupted image file
- **THEN** method returns `Result::Err(Error)` with `ErrorType::CorruptedImage`

### Requirement: Error struct provides detailed information
The Error struct SHALL contain a type field, message field, and optional context field to enable users to understand and handle errors appropriately.

#### Scenario: Error includes type and message
- **WHEN** an error occurs during palette extraction
- **THEN** the returned Error struct has a non-nil `type` field (ErrorType enum) and a non-empty `message` field (String)

#### Scenario: Error includes context when available
- **WHEN** an error occurs that has additional context (e.g., file path, image dimensions)
- **THEN** the returned Error struct includes a `context` hash with relevant key-value pairs

### Requirement: Raising variant methods use bang suffix
Methods that raise exceptions instead of returning Result types SHALL use the `!` suffix following Crystal naming conventions.

#### Scenario: Raising method on success
- **WHEN** user calls `PrismatIQ.get_palette!("valid.png", options)` with a valid image
- **THEN** method returns `Array(RGB)` directly without Result wrapper

#### Scenario: Raising method on error
- **WHEN** user calls `PrismatIQ.get_palette!("invalid.png", options)` with an invalid file
- **THEN** method raises an exception with error message

### Requirement: Deprecated methods emit warnings
Methods marked as deprecated SHALL emit deprecation warnings at compile time guiding users to the new API.

#### Scenario: Deprecated method shows warning
- **WHEN** user compiles code using deprecated `get_palette(path, color_count, quality, threads)` signature
- **THEN** compiler emits deprecation warning suggesting `get_palette(path, options)`

#### Scenario: Deprecated method still works
- **WHEN** user calls deprecated method at runtime
- **THEN** method functions correctly to maintain backward compatibility during migration period

### Requirement: No sentinel error values
The API SHALL NOT use sentinel values (e.g., `[RGB.new(0, 0, 0)]`) to indicate errors. All error conditions MUST return `Result::Err`.

#### Scenario: Black color returned as valid result
- **WHEN** palette extraction results in black color `RGB.new(0, 0, 0)` as a legitimate color
- **THEN** method returns `Result::Ok([RGB.new(0, 0, 0)])` distinguishable from error state

#### Scenario: Error never returns color array
- **WHEN** an error occurs during processing
- **THEN** method returns `Result::Err(Error)`, never an array of RGB values

### Requirement: Error taxonomy covers all failure modes
The ErrorType enum SHALL include variants for all possible failure scenarios in the library.

#### Scenario: File system errors
- **WHEN** file cannot be read due to permissions, missing file, or I/O errors
- **THEN** error type is one of: `FileNotFound`, `InvalidImagePath`, or `ProcessingFailed` with relevant context

#### Scenario: Image format errors
- **WHEN** image file is corrupted or has unsupported format
- **THEN** error type is `CorruptedImage` or `UnsupportedFormat`

#### Scenario: Parameter validation errors
- **WHEN** user provides invalid Options (negative color count, invalid quality)
- **THEN** error type is `InvalidOptions`

## REMOVED Requirements

### Requirement: PaletteResult struct
**Reason:** Duplicate functionality of standard Result type creates API confusion  
**Migration:** Replace `PaletteResult` with standard `Result(Array(RGB), Error)` type. Access result value via `.value` on Ok, `.error` on Err.

### Requirement: Sentinel error value
**Reason:** Ambiguous return value indistinguishable from legitimate black pixels  
**Migration:** Check for `Result::Err` instead of comparing to `[RGB.new(0, 0, 0)]`
