## MODIFIED Requirements

### Requirement: Palette extraction API uses Result type and Options parameter
The system SHALL provide a consistent palette extraction API that uses `Result(Array(RGB), String)` return type and `Options` parameter object exclusively, replacing ambiguous sentinel values and multiple method overloads.

#### Scenario: Successful palette extraction returns Result.ok
- **WHEN** calling `get_palette_or_error` with valid image path and parameters
- **THEN** method returns `Result(Array(RGB), String).ok(palette)` with actual color palette

#### Scenario: Failed palette extraction returns Result.err
- **WHEN** calling `get_palette_or_error` with invalid image path or corrupted file
- **THEN** method returns `Result(Array(RGB), String).err(error_message)` with descriptive error message

#### Scenario: Primary API uses Options parameter exclusively
- **WHEN** calling `get_palette` method
- **THEN** it accepts only `Options` parameter object instead of multiple keyword arguments

#### Scenario: Deprecated methods include clear migration guidance
- **WHEN** calling deprecated methods with keyword arguments
- **THEN** they include `@[Deprecated]` annotations with clear migration instructions

## REMOVED Requirements

### Requirement: Sentinel value error handling
**Reason**: Ambiguous and error-prone - impossible to distinguish between actual black pixels and errors
**Migration**: Use new `get_palette_or_error` method which returns `Result(Array(RGB), String)` for explicit error handling

### Requirement: Multiple method overloads with keyword arguments
**Reason**: Creates confusion and maintenance burden
**Migration**: Use `Options` parameter object with named fields for all configuration