## 1. CPU Cores Module Refactoring

- [ ] 1.1 Reduce complexity in `cores` method (27 → ≤12)
- [ ] 1.2 Reduce complexity in `l2_cache_bytes` method (22 → ≤12)
- [ ] 1.3 Verify Ameba passes for cpu_cores.cr

## 2. Tempfile Helper Refactoring

- [ ] 2.1 Reduce complexity in `create_and_write` method (23 → ≤12)
- [ ] 2.2 Verify Ameba passes for tempfile_helper.cr

## 3. BMP Parser Refactoring

- [ ] 3.1 Reduce complexity in `parse_header_fields_only` method (13 → ≤12)
- [ ] 3.2 Reduce complexity in `parse_header` method (14 → ≤12)
- [ ] 3.3 Verify Ameba passes for bmp_parser.cr

## 4. ICO Extractor Refactoring

- [ ] 4.1 Reduce complexity in `extract_from_ico` method (16 → ≤12)
- [ ] 4.2 Reduce complexity in `best_bmp_entry` method (13 → ≤12)
- [ ] 4.3 Verify Ameba passes for ico.cr

## 5. Color Extractor Refactoring

- [ ] 5.1 Reduce complexity in `extract_from_buffer` method (16 → ≤12)
- [ ] 5.2 Verify Ameba passes for color_extractor.cr

## 6. Main Module Refactoring

- [ ] 6.1 Reduce complexity in `quantize` method (22 → ≤12)
- [ ] 6.2 Verify Ameba passes for prismatiq.cr

## 7. Final Verification

- [ ] 7.1 Run full test suite
- [ ] 7.2 Run Ameba on all source files
- [ ] 7.3 Verify no regressions in functionality