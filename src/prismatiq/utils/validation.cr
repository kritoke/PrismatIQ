require "../errors"

module PrismatIQ
  # Input validation utilities for secure image processing.
  #
  # This module provides comprehensive validation for file paths, options,
  # and IO streams to prevent security vulnerabilities like path traversal,
  # directory access, and resource exhaustion.
  #
  # # Thread Safety
  #
  # - **Pure Functions**: All validation methods are pure functions with no side effects
  # - **Fully Thread-Safe**: Can be called concurrently from multiple fibers
  # - **No Shared State**: No mutable state between method calls
  #
  # # Security Features
  #
  # - **Path Traversal Prevention**: Blocks `..` and `~` in file paths
  # - **System Directory Protection**: Prevents access to `/etc`, `/sys`, `/proc`
  # - **File Size Limits**: Enforces 100MB maximum file size
  # - **Format Validation**: Only allows supported image formats
  # - **Options Validation**: Validates parameter ranges (color_count, quality, etc.)
  #
  # # Usage
  #
  # ```
  # # Validate file path before processing
  # result = Validation.validate_file_path(user_input)
  # if result.ok?
  #   safe_path = result.value
  #   # Process image...
  # end
  # ```
  module Utils
    module Validation
      MAX_FILE_SIZE        = 100 * 1024 * 1024 # 100MB
      SUPPORTED_EXTENSIONS = [".png", ".jpg", ".jpeg", ".gif", ".bmp", ".ico", ".webp", ".tiff", ".tif", ".svg"]

      def self.validate_file_path(path : String) : Result(String, Error)
        return Result(String, Error).err(Error.invalid_image_path(path, "Path is empty")) if path.empty?

        return Result(String, Error).err(Error.new(ErrorType::InvalidImagePath, "Null byte in path not allowed")) if path.includes?('\0')

        decoded_path = url_decode_path(path)
        return Result(String, Error).err(Error.invalid_image_path(path, "Directory traversal not allowed")) if contains_traversal?(path) || contains_traversal?(decoded_path)

        return Result(String, Error).err(Error.file_not_found(path)) unless File.exists?(path)

        real_path_res = validate_realpath(path)
        return real_path_res if real_path_res.is_a?(Result(String, Error)) && !real_path_res.ok?

        real_path = real_path_res.as(String)
        return Result(String, Error).err(Error.invalid_image_path(path, "Access to system directories not allowed")) if system_directory?(real_path)

        ext = File.extname(path).downcase
        return Result(String, Error).err(Error.unsupported_format(ext)) unless SUPPORTED_EXTENSIONS.includes?(ext)

        size_result = validate_file_size(path)
        return size_result if size_result.is_a?(Result(String, Error))

        Result(String, Error).ok(path)
      end

      private def self.validate_realpath(path : String) : Result(String, Error) | String
        File.realpath(path)
      rescue ex : Exception
        Result(String, Error).err(Error.invalid_image_path(path, "Cannot resolve path: #{ex.message}"))
      end

      private def self.system_directory?(path : String) : Bool
        path.starts_with?("/etc/") || path.starts_with?("/sys/") || path.starts_with?("/proc/")
      end

      private def self.validate_file_size(path : String) : Result(String, Error) | Bool
        size = File.size(path)
        return Result(String, Error).err(Error.invalid_image_path(path, "File size exceeds 100MB limit")) if size > MAX_FILE_SIZE
        return Result(String, Error).err(Error.corrupted_image("File is empty")) if size == 0
        true
      rescue ex : Exception
        Result(String, Error).err(Error.invalid_image_path(path, "Cannot read file: #{ex.message}"))
      end

      private def self.url_decode_path(path : String) : String
        decoded = path
        3.times do
          new_decoded = URI.decode(decoded)
          break if new_decoded == decoded
          decoded = new_decoded
        end
        decoded
      end

      private def self.contains_traversal?(path : String) : Bool
        lower = path.downcase
        lower.includes?("..") || lower.includes?("~") ||
          lower.includes?("%2e") || lower.includes?("%252e") ||
          lower.includes?("%2f") || lower.includes?("%5c") ||
          lower.includes?("%7e")
      end

      def self.validate_options(options : Options) : Result(Options, Error)
        options.validate!
        Result(Options, Error).ok(options)
      rescue ex : ValidationError
        Result(Options, Error).err(Error.invalid_options("options", "invalid", ex.message || "Validation failed"))
      end

      def self.validate_io(io : IO) : Result(IO, Error)
        # Check if IO is readable
        # Try to peek at the first few bytes to validate it's an image
        pos = io.pos rescue 0
        header = io.peek(8) rescue nil

        if header && header.size > 0
          # Check for common image file signatures
          unless image_header?(header)
            return Result(IO, Error).err(Error.unsupported_format("Unknown image format"))
          end
        end

        # Reset position if possible
        io.pos = pos rescue nil

        Result(IO, Error).ok(io)
      rescue ex : Exception
        Result(IO, Error).err(Error.corrupted_image("Cannot read from IO: #{ex.message}"))
      end

      private def self.image_header?(header : Bytes) : Bool
        # PNG: 89 50 4E 47 0D 0A 1A 0A
        return true if header[0..3] == Bytes[0x89, 0x50, 0x4E, 0x47]

        # JPEG: FF D8 FF
        return true if header[0..2] == Bytes[0xFF, 0xD8, 0xFF]

        # GIF: 47 49 46 38
        return true if header[0..3] == Bytes[0x47, 0x49, 0x46, 0x38]

        # BMP: 42 4D
        return true if header[0..1] == Bytes[0x42, 0x4D]

        # ICO: 00 00 01 00
        return true if header[0..3] == Bytes[0x00, 0x00, 0x01, 0x00]

        # WebP: 52 49 46 46 ... 57 45 42 50
        return true if header[0..3] == Bytes[0x52, 0x49, 0x46, 0x46]

        # SVG: starts with <?xml or <svg (text-based, check for '<')
        return true if header[0] == 0x3C # '<' character

        false
      end
    end
  end
end
