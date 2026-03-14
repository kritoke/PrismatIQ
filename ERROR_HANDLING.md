# Error Handling

PrismatIQ v0.5.0 provides comprehensive error handling through two main patterns: **Result-based** and **Exception-based**.

## Result-Based Error Handling (Recommended)

The primary APIs (`get_palette_v2`, `get_palette_from_ico_v2`) return a `Result(Array(RGB), Error)` type that explicitly handles both success and failure cases.

### Basic Usage

```crystal
result = PrismatIQ.get_palette_v2("image.png", options)

case result
when .ok?
  colors = result.value
  colors.each { |color| puts color.to_hex }
when .err?
  error = result.error
  puts "Error type: #{error.type}"
  puts "Message: #{error.message}"  
  if error.context
    puts "Context: #{error.context}"
  end
end
```

### Error Types

The `Error` struct contains structured error information:

- **`type`**: `ErrorType` enum with specific error categories:
  - `FileNotFound` - File doesn't exist or cannot be accessed
  - `InvalidImagePath` - Path validation failed (directory traversal, system directories)
  - `UnsupportedFormat` - Image format not supported  
  - `CorruptedImage` - Image data is corrupt or empty
  - `InvalidOptions` - Parameter validation failed (out of range values)
  - `ProcessingFailed` - General processing error

- **`message`**: Human-readable error message
- **`context`**: Hash with additional context (file path, parameter values, etc.)

### Functional Result Operations

The `Result` type supports functional programming patterns:

```crystal
# Transform successful results
hex_colors = PrismatIQ.get_palette_v2("image.png", options)
                  .map { |colors| colors.map(&.to_hex) }

# Provide default values for errors  
default_palette = [PrismatIQ::RGB.new(0, 0, 0)]
palette = PrismatIQ.get_palette_v2("image.png", options)
                .value_or(default_palette)

# Chain multiple operations
result = PrismatIQ.get_palette_v2("image1.png", options)
         .flat_map { |colors1| 
           PrismatIQ.get_palette_v2("image2.png", options)
                    .map { |colors2| colors1 + colors2 }
         }

# Transform errors
result = PrismatIQ.get_palette_v2("image.png", options)
         .map_error { |e| 
           # Log original error and provide user-friendly message
           Log.error("Palette extraction failed: #{e.message}")
           PrismatIQ::Error.processing_failed("Could not process image")
         }
```

## Exception-Based Error Handling

For simpler use cases where you prefer traditional exception handling, use the `!` variant APIs (`get_palette_v2!`, etc.).

### Basic Usage

```crystal
begin
  colors = PrismatIQ.get_palette_v2!("image.png", options)
  colors.each { |color| puts color.to_hex }
rescue ex : PrismatIQ::ValidationError
  puts "Invalid parameters: #{ex.message}"
rescue ex : Exception
  puts "Processing failed: #{ex.message}"
end
```

### When to Use Each Pattern

**Use Result-based when:**
- You want explicit error handling without exceptions
- You're building robust applications that should handle all error cases
- You want to use functional programming patterns
- You're processing many images and want to continue on individual failures

**Use Exception-based when:**
- You have simple scripts or applications
- You prefer traditional try/catch error handling
- Errors are truly exceptional and should stop execution
- You want cleaner code for happy-path scenarios

## Error Handling Best Practices

### 1. Always Handle Both Success and Failure

Don't assume palette extraction will always succeed:

```crystal
# ❌ Don't do this - will crash on error
colors = PrismatIQ.get_palette_v2("image.png", options).value

# ✅ Do this instead
if result.ok?
  # handle success
else
  # handle error
end
```

### 2. Use Contextual Error Messages

The structured `Error` type provides rich context:

```crystal
case result.error.type
when .file_not_found?
  puts "Image file not found: #{result.error.context["path"]?}"
when .invalid_options?
  puts "Invalid parameter #{result.error.context["field"]?}: #{result.error.message}"
when .corrupted_image?
  puts "Image appears to be corrupted or empty"
else
  puts "Unexpected error: #{result.error.message}"
end
```

### 3. Graceful Degradation

Provide fallback behavior for non-critical operations:

```crystal
def extract_palette_with_fallback(path, options)
  result = PrismatIQ.get_palette_v2(path, options)
  return result.value if result.ok?
  
  # Fallback to default palette
  [PrismatIQ::RGB.new(255, 255, 255), PrismatIQ::RGB.new(0, 0, 0)]
end
```

### 4. Logging and Monitoring

Use the structured error information for better observability:

```crystal
result = PrismatIQ.get_palette_v2(path, options)
if result.err?
  Log.warn("Palette extraction failed", 
           type: result.error.type.to_s,
           message: result.error.message,
           context: result.error.context)
end
```

## Common Error Scenarios

### File Not Found
- **Cause**: Image file doesn't exist or path is incorrect
- **Solution**: Validate file paths before processing

### Invalid Image Path  
- **Cause**: Path contains directory traversal (`..`), home directory (`~`), or system directories
- **Solution**: Use sanitized, application-controlled paths

### Unsupported Format
- **Cause**: File extension not in supported formats (`.png`, `.jpg`, `.jpeg`, `.gif`, `.bmp`, `.ico`, `.webp`, `.tiff`, `.tif`)
- **Solution**: Validate file extensions or convert to supported format first

### Corrupted Image
- **Cause**: File is empty, truncated, or contains invalid image data  
- **Solution**: Handle gracefully with fallback palettes

### Invalid Options
- **Cause**: Parameters out of valid ranges (`color_count < 1`, `quality < 1`, negative `threads`, etc.)
- **Solution**: Validate user input before creating `Options`

### Processing Failed
- **Cause**: Unexpected errors during processing (out of memory, internal errors)
- **Solution**: Implement retry logic or graceful degradation