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
      SUPPORTED_EXTENSIONS = [".png", ".jpg", ".jpeg", ".gif", ".bmp", ".ico", ".webp", ".tiff", ".tif"]

      def self.validate_file_path(path : String) : Result(String, Error)
        return Result(String, Error).err(Error.invalid_image_path(path, "Path is empty")) if path.empty?

        if path.includes?('\0')
          return Result(String, Error).err(Error.new(ErrorType::InvalidImagePath, "Null byte in path not allowed"))
        end

        decoded_path = url_decode_path(path)

        if contains_traversal?(path) || contains_traversal?(decoded_path)
          return Result(String, Error).err(Error.invalid_image_path(path, "Directory traversal not allowed"))
        end

        unless File.exists?(path)
          return Result(String, Error).err(Error.file_not_found(path))
        end

        begin
          real_path = File.realpath(path)
        rescue ex : Exception
          return Result(String, Error).err(Error.invalid_image_path(path, "Cannot resolve path: #{ex.message}"))
        end

        if real_path.starts_with?("/etc/") || real_path.starts_with?("/sys/") || real_path.starts_with?("/proc/")
          return Result(String, Error).err(Error.invalid_image_path(path, "Access to system directories not allowed"))
        end

        ext = File.extname(path).downcase
        unless SUPPORTED_EXTENSIONS.includes?(ext)
          return Result(String, Error).err(Error.unsupported_format(ext))
        end

        begin
          size = File.size(path)
          if size > MAX_FILE_SIZE
            return Result(String, Error).err(Error.invalid_image_path(path, "File size exceeds 100MB limit"))
          end

          if size == 0
            return Result(String, Error).err(Error.corrupted_image("File is empty"))
          end
        rescue ex : Exception
          return Result(String, Error).err(Error.invalid_image_path(path, "Cannot read file: #{ex.message}"))
        end

        Result(String, Error).ok(path)
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
        return true if path.includes?("..")
        return true if path.includes?("~")
        return true if path.includes?("%2e") || path.includes?("%2E")
        return true if path.includes?("%252e") || path.includes?("%252E")
        return true if path.includes?("%2f") || path.includes?("%2F")
        return true if path.includes?("%5c") || path.includes?("%5C")
        return true if path.includes?("%7e") || path.includes?("%7E")
        false
      end

      def self.validate_options(options : Options) : Result(Options, Error)
        begin
          options.validate!
          Result(Options, Error).ok(options)
        rescue ex : ValidationError
          Result(Options, Error).err(Error.invalid_options("options", "invalid", ex.message || "Validation failed"))
        end
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

        false
      end
    end
  end
end
