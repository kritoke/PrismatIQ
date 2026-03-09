## ADDED Requirements

### Requirement: Centralized YIQ color space conversion logic
The system SHALL centralize all YIQ color space conversion and quantization logic in a dedicated `YIQConverter` module to eliminate duplication and ensure consistency across the codebase.

#### Scenario: RGB to YIQ conversion is centralized
- **WHEN** converting RGB values to YIQ color space
- **THEN** all conversions use `YIQConverter.from_rgb(r, g, b)` method

#### Scenario: Quantized YIQ conversion is centralized
- **WHEN** converting RGB values to quantized YIQ for histogram indexing
- **THEN** all conversions use `YIQConverter.quantize_from_rgb(r, g, b)` method

#### Scenario: Histogram index conversion is centralized
- **WHEN** converting quantized YIQ values to histogram indices
- **THEN** all conversions use `YIQConverter.to_index(y, i, q)` method

#### Scenario: No duplicate YIQ conversion logic exists
- **WHEN** examining the source code for YIQ conversion logic
- **THEN** no duplicate implementations are found outside the `YIQConverter` module

#### Scenario: YIQConverter module is well-documented
- **WHEN** examining the `YIQConverter` module
- **THEN** it includes comprehensive documentation and examples for all public methods

#### Scenario: YIQConverter handles edge cases properly
- **WHEN** calling YIQConverter methods with extreme RGB values
- **THEN** methods handle edge cases properly and return valid results