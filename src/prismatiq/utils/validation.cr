require "../errors"

module PrismatIQ
  module Utils
    module Validation
      MAX_FILE_SIZE        = 100 * 1024 * 1024
      SUPPORTED_EXTENSIONS = [".png", ".jpg", ".jpeg", ".gif", ".bmp", ".ico", ".webp", ".tiff", ".tif", ".svg"]

      def self.validate_file_path(path : String) : Result(String, Error)
        return Result(String, Error).err(Error.invalid_image_path(path, "Path is empty")) if path.empty?

        return Result(String, Error).err(Error.new(ErrorType::InvalidImagePath, "Null byte in path not allowed")) if path.includes?('\0')

        decoded_path = url_decode_path(path)
        return Result(String, Error).err(Error.invalid_image_path(path, "Directory traversal not allowed")) if contains_traversal?(path) || contains_traversal?(decoded_path)

        return Result(String, Error).err(Error.file_not_found(path)) unless File.exists?(path)

        real_path_res = validate_realpath(path)
        return real_path_res if real_path_res.err?

        real_path = real_path_res.value
        return Result(String, Error).err(Error.invalid_image_path(path, "Access to system directories not allowed")) if system_directory?(real_path)

        ext = File.extname(path).downcase
        return Result(String, Error).err(Error.unsupported_format(ext)) unless SUPPORTED_EXTENSIONS.includes?(ext)

        size_result = validate_file_size(path)
        return size_result if size_result.err?

        Result(String, Error).ok(path)
      end

      private def self.validate_realpath(path : String) : Result(String, Error)
        real = File.realpath(path)
        Result(String, Error).ok(real)
      rescue ex : Exception
        Result(String, Error).err(Error.invalid_image_path(path, "Cannot resolve path: #{ex.message}"))
      end

      private def self.system_directory?(path : String) : Bool
        path.starts_with?("/etc/") || path.starts_with?("/sys/") || path.starts_with?("/proc/") ||
          path.starts_with?("/dev/") || path.starts_with?("/boot/") || path.starts_with?("/root/") ||
          path.starts_with?("/usr/") || path.starts_with?("/var/") || path.starts_with?("/lib/") ||
          path.starts_with?("/sbin/") || path.starts_with?("/bin/") || path == "/"
      end

      private def self.validate_file_size(path : String) : Result(String, Error)
        size = File.size(path)
        return Result(String, Error).err(Error.invalid_image_path(path, "File size exceeds 100MB limit")) if size > MAX_FILE_SIZE
        return Result(String, Error).err(Error.corrupted_image("File is empty")) if size == 0
        Result(String, Error).ok(path)
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
        parts = path.split('/')
        parts.each do |part|
          return true if part == ".." || part == "~" || part.starts_with?("~")
        end
        decoded = url_decode_path(path)
        return false if decoded == path
        parts = decoded.split('/')
        parts.each do |part|
          return true if part == ".." || part == "~" || part.starts_with?("~")
        end
        false
      end

      def self.validate_options(options : Options) : Result(Options, Error)
        options.validate!
        Result(Options, Error).ok(options)
      rescue ex : ValidationError
        Result(Options, Error).err(Error.invalid_options("options", "invalid", ex.message || "Validation failed"))
      end

      def self.validate_io(io : IO) : Result(IO, Error)
        pos = io.pos rescue 0
        header = io.peek(8) rescue nil

        if header && header.size > 0
          unless image_header?(header)
            return Result(IO, Error).err(Error.unsupported_format("Unknown image format"))
          end
        end

        begin
          io.pos = pos
        rescue ex : Exception
          return Result(IO, Error).err(Error.corrupted_image("Cannot reset IO position: #{ex.message}"))
        end

        Result(IO, Error).ok(io)
      rescue ex : Exception
        Result(IO, Error).err(Error.corrupted_image("Cannot read from IO: #{ex.message}"))
      end

      private def self.image_header?(header : Bytes) : Bool
        return true if header[0..3] == Bytes[0x89, 0x50, 0x4E, 0x47]
        return true if header[0..2] == Bytes[0xFF, 0xD8, 0xFF]
        return true if header[0..3] == Bytes[0x47, 0x49, 0x46, 0x38]
        return true if header[0..1] == Bytes[0x42, 0x4D]
        return true if header[0..3] == Bytes[0x00, 0x00, 0x01, 0x00]
        return true if header[0..3] == Bytes[0x52, 0x49, 0x46, 0x46]

        if header[0] == 0x3C && header.size >= 4
          svg_sig = Bytes[0x3C_u8, 0x73_u8, 0x76_u8, 0x67_u8]
          xml_sig = Bytes[0x3C_u8, 0x3F_u8, 0x78_u8, 0x6D_u8]
          return true if header[0..3] == svg_sig || header[0..3] == xml_sig
        end

        false
      end
    end
  end
end
