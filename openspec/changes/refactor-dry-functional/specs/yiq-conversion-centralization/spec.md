## ADDED Requirements

### Requirement: YIQConverter provides centralized color space conversion
The system SHALL provide a YIQConverter module that centralizes all YIQ color space conversion and quantization logic.

#### Scenario: RGB to YIQ conversion works correctly
- **WHEN** YIQConverter.from_rgb is called with valid RGB values
- **THEN** method returns Color object with correct Y, I, Q components using standard NTSC coefficients

#### Scenario: RGB to quantized YIQ conversion works correctly  
- **WHEN** YIQConverter.quantize_from_rgb is called with valid RGB values
- **THEN** method returns tuple of Int32 values representing 5-bit quantized Y, I, Q components

#### Scenario: YIQ to index conversion works correctly
- **WHEN** YIQConverter.to_index is called with valid quantized Y, I, Q values
- **THEN** method returns correct histogram index using bit shifting (y << 10) | (i << 5) | q

## MODIFIED Requirements

### Requirement: Core module uses YIQConverter for all color operations
The PrismatIQ core module SHALL use YIQConverter instead of inline YIQ conversion logic in all methods.

#### Scenario: Palette extraction uses centralized YIQ conversion
- **WHEN** get_palette_from_buffer processes RGBA pixels
- **THEN** method uses YIQConverter.quantize_from_rgb for pixel quantization

#### Scenario: Color sorting uses centralized YIQ conversion
- **WHEN** sort_by_popularity orders palette colors by frequency
- **THEN** method uses YIQConverter.quantize_from_rgb for color-to-histogram-index conversion

#### Scenario: Color class uses centralized YIQ conversion
- **WHEN** Color.from_rgb creates Color from RGB components
- **THEN** method uses YIQConverter.from_rgb for conversion