## ADDED Requirements

### Requirement: Replace shell commands with proper system APIs
The system SHALL use Crystal's proper system call APIs or cross-platform library calls instead of shell-based backtick commands for CPU detection and system information gathering to eliminate security vulnerabilities and improve reliability.

#### Scenario: CPU core detection uses Process module instead of backticks
- **WHEN** calling `CPU.cores` method
- **THEN** implementation uses Crystal's `Process` module or direct system calls instead of ``sysctl -n hw.ncpu``

#### Scenario: L2 cache size detection uses proper system APIs
- **WHEN** calling `CPU.l2_cache_bytes` method  
- **THEN** implementation uses proper system APIs instead of ``sysctl -n hw.l2cachesize``

#### Scenario: System calls include proper error handling
- **WHEN** system API calls fail or are unsupported
- **THEN** methods return appropriate default values or nil instead of crashing

#### Scenario: Platform-specific fallbacks are implemented
- **WHEN** running on platforms where system APIs are not available
- **THEN** methods implement proper fallback logic with clear documentation of limitations

#### Scenario: No shell injection vulnerabilities exist
- **WHEN** security analysis is performed on the codebase
- **THEN** no backtick-based system calls are found in the source code