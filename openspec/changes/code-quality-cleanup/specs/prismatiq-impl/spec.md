## MODIFIED Requirements

### Requirement: Code quality meets Ameba complexity thresholds
The codebase SHALL maintain cyclomatic complexity below 12 points in all methods to ensure readability and maintainability.

#### Scenario: CPU cores detection complexity
- **WHEN** cpu_cores.cr is analyzed by Ameba
- **THEN** the `cores` method has complexity ≤ 12
- **AND** the `l2_cache_bytes` method has complexity ≤ 12

#### Scenario: Tempfile helper complexity
- **WHEN** tempfile_helper.cr is analyzed by Ameba
- **THEN** the `create_and_write` method has complexity ≤ 12

#### Scenario: BMP parser complexity
- **WHEN** bmp_parser.cr is analyzed by Ameba
- **THEN** the `parse_header_fields_only` method has complexity ≤ 12
- **AND** the `parse_header` method has complexity ≤ 12

#### Scenario: ICO extractor complexity
- **WHEN** ico.cr is analyzed by Ameba
- **THEN** the `extract_from_ico` method has complexity ≤ 12
- **AND** the `best_bmp_entry` method has complexity ≤ 12

#### Scenario: Color extractor complexity
- **WHEN** color_extractor.cr is analyzed by Ameba
- **THEN** the `extract_from_buffer` method has complexity ≤ 12

#### Scenario: Main module complexity
- **WHEN** prismatiq.cr is analyzed by Ameba
- **THEN** the `quantize` method has complexity ≤ 12