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
        # Check for nil or empty
        return Result(String, Error).err(Error.invalid_image_path(path, "Path is empty")) if path.empty?

        # Check for directory traversal attempts
        if path.includes?("..") || path.includes?("~")
          return Result(String, Error).err(Error.invalid_image_path(path, "Directory traversal not allowed"))
        end

        # Check if path is absolute and trying to access system directories
        expanded = File.expand_path(path)
        if expanded.starts_with?("/etc/") || expanded.starts_with?("/sys/") || expanded.starts_with?("/proc/")
          return Result(String, Error).err(Error.invalid_image_path(path, "Access to system directories not allowed"))
        end

        # Check file exists
        unless File.exists?(path)
          return Result(String, Error).err(Error.file_not_found(path))
        end

        # Check file extension
        ext = File.extname(path).downcase
        unless SUPPORTED_EXTENSIONS.includes?(ext)
          return Result(String, Error).err(Error.unsupported_format(ext))
        end

        # Check file size
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

      def self.validate_options(options : Options) : Result(Options, Error)
        # Validate color_count
        if options.color_count < 1
          return Result(Options, Error).err(
            Error.invalid_options("color_count", options.color_count.to_s, "must be >= 1")
          )
        end

        if options.color_count > 256
          return Result(Options, Error).err(
            Error.invalid_options("color_count", options.color_count.to_s, "must be <= 256")
          )
        end

        # Validate quality
        if options.quality < 1
          return Result(Options, Error).err(
            Error.invalid_options("quality", options.quality.to_s, "must be >= 1")
          )
        end

        if options.quality > 100
          return Result(Options, Error).err(
            Error.invalid_options("quality", options.quality.to_s, "must be <= 100")
          )
        end

        # Validate threads
        if options.threads < 0
          return Result(Options, Error).err(
            Error.invalid_options("threads", options.threads.to_s, "must be >= 0")
          )
        end

        # Validate alpha_threshold (should be 0-255)
        if options.alpha_threshold > 255_u8
          return Result(Options, Error).err(
            Error.invalid_options("alpha_threshold", options.alpha_threshold.to_s, "must be 0-255")
          )
        end

        Result(Options, Error).ok(options)
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
