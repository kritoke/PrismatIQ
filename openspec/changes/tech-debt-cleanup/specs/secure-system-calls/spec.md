# Spec: Secure System Calls

**Capability:** secure-system-calls  
**Status:** Proposed  
**Version:** 1.0  

## ADDED Requirements

### Requirement: No shell command execution
The library SHALL NOT execute shell commands using backticks, system(), or similar methods. All system interaction MUST use Crystal's native APIs or LibC bindings.

#### Scenario: CPU count without shell
- **WHEN** library needs to detect CPU count
- **THEN** implementation uses LibC.sysctl or /proc filesystem, not `sysctl` shell command

#### Scenario: No backticks in codebase
- **WHEN** searching codebase for backtick characters
- **THEN** no shell command execution patterns are found in production code

### Requirement: Platform-specific implementations
System information retrieval SHALL use compile-time platform detection to select appropriate implementation for each operating system.

#### Scenario: macOS CPU detection
- **WHEN** running on macOS platform
- **THEN** CPU count uses LibC.sysctlbyname with "hw.ncpu" parameter

#### Scenario: Linux CPU detection
- **WHEN** running on Linux platform
- **THEN** CPU count reads and parses /proc/cpuinfo

#### Scenario: Unknown platform fallback
- **WHEN** running on unsupported platform
- **THEN** CPU count returns safe default value of 1

### Requirement: Input validation for file paths
File path inputs SHALL be validated to prevent directory traversal and ensure paths reference expected file types.

#### Scenario: Reject directory traversal
- **WHEN** user provides path containing ".." or absolute path outside expected directory
- **THEN** method returns `Result::Err(Error)` with `InvalidImagePath` type

#### Scenario: Validate file extension
- **WHEN** user provides path with unsupported extension (not .png, .jpg, .ico, etc.)
- **THEN** method returns `Result::Err(Error)` with `UnsupportedFormat` type

### Requirement: Maximum file size limits
The library SHALL enforce maximum file size limits to prevent denial-of-service attacks from extremely large files.

#### Scenario: Reject oversized files
- **WHEN** user provides image file larger than 100MB
- **THEN** method returns `Result::Err(Error)` with `InvalidOptions` type and context includes "max_size: 104857600"

#### Scenario: Accept normal files
- **WHEN** user provides image file smaller than 100MB
- **THEN** file is processed normally without size-related errors

### Requirement: Options parameter validation
All Options struct fields SHALL be validated against acceptable ranges before processing begins.

#### Scenario: Validate color count
- **WHEN** user provides Options with color_count outside range 1-256
- **THEN** method returns `Result::Err(Error)` with `InvalidOptions` type

#### Scenario: Validate quality parameter
- **WHEN** user provides Options with quality outside range 1-100
- **THEN** method returns `Result::Err(Error)` with `InvalidOptions` type

#### Scenario: Validate thread count
- **WHEN** user provides Options with negative thread count
- **THEN** method returns `Result::Err(Error)` with `InvalidOptions` type

### Requirement: Safe temporary file handling
Temporary files created during processing (e.g., ICO parsing) SHALL use secure tempfile creation with proper cleanup.

#### Scenario: Tempfile in secure location
- **WHEN** library creates temporary file for ICO processing
- **THEN** file is created using Crystal's Tempfile class in system temp directory

#### Scenario: Tempfile cleanup on success
- **WHEN** processing completes successfully
- **THEN** all temporary files are deleted

#### Scenario: Tempfile cleanup on error
- **WHEN** processing fails with error
- **THEN** all temporary files are deleted in ensure block

### Requirement: No sensitive data in errors
Error messages and context SHALL NOT include sensitive information such as full file paths, user names, or system configuration details.

#### Scenario: Generic file path in error
- **WHEN** file not found error occurs
- **THEN** error message includes basename only, not full path

#### Scenario: No system info in errors
- **WHEN** error occurs during system info retrieval
- **THEN** error context does not include system configuration details

## REMOVED Requirements

### Requirement: Shell command for CPU detection
**Reason:** Shell command execution creates injection risk and is not portable across platforms  
**Migration:** CPU detection now uses platform-specific native APIs. No user code changes required.
