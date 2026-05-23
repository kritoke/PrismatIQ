require "../errors"

module PrismatIQ
  module Utils
    module Validation
      MAX_FILE_SIZE        = 100 * 1024 * 1024
      SUPPORTED_EXTENSIONS = [".png", ".jpg", ".jpeg", ".gif", ".bmp", ".ico", ".webp", ".tiff", ".tif", ".svg"]

      # Expanded system directory protection for security.
      # Blocks access to OS-critical directories across all platforms.
      private SYSTEM_DIRECTORIES = {
        # Linux
        "/etc/", "/sys/", "/proc/", "/dev/", "/boot/", "/root/",
        "/usr/", "/var/", "/lib/", "/sbin/", "/bin/",
        "/run/", "/snap/", "/srv/", "/opt/", "/mnt/", "/media/",
        "/lost+found", "/.snapshots",
        # macOS
        "/System/", "/Library/", "/Applications/", "/bin/", "/sbin/",
        "/usr/lib/", "/usr/sbin/", "/usr/bin/", "/var/log/",
        "/var/root/", "/private/",
        # Windows (using forward slashes for cross-platform compatibility)
        "C:/Windows/", "C:/Program Files/", "C:/Program Files (x86)/",
        "C:/Boot/", "C:/Recovery/", "C:/System Volume Information/",
      }

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

        ext = File.extname(real_path).downcase
        return Result(String, Error).err(Error.unsupported_format(ext)) unless SUPPORTED_EXTENSIONS.includes?(ext)

        size_result = validate_file_size(real_path)
        return size_result if size_result.err?

        Result(String, Error).ok(real_path)
      end

      private def self.validate_realpath(path : String) : Result(String, Error)
        real = File.realpath(path)
        Result(String, Error).ok(real)
      rescue ex : File::Error | ArgumentError
        Result(String, Error).err(Error.invalid_image_path(path, "Cannot resolve path: #{ex.message}"))
      end

      private def self.system_directory?(path : String) : Bool
        # Fast path: check exact matches
        return true if path == "/"
        return true if path == "C:/" || path == "C:"

        # Normalize path separators for consistent checking
        normalized = path.gsub("\\", "/")

        # Check against known system directories
        SYSTEM_DIRECTORIES.each do |sys_dir|
          return true if normalized.starts_with?(sys_dir)
        end

        false
      end

      private def self.validate_file_size(path : String) : Result(String, Error)
        size = File.size(path)
        return Result(String, Error).err(Error.invalid_image_path(path, "File size exceeds 100MB limit")) if size > MAX_FILE_SIZE
        return Result(String, Error).err(Error.corrupted_image("File is empty")) if size == 0
        Result(String, Error).ok(path)
      rescue ex : File::Error | IO::Error
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

        # SVG: "<?xml" or "<svg"
        if header.size >= 5
          return true if header[0..4] == Bytes[0x3C_u8, 0x3F_u8, 0x78_u8, 0x6D_u8, 0x6C_u8]
          return true if header[0..3] == Bytes[0x3C_u8, 0x73_u8, 0x76_u8, 0x67_u8]
        end

        false
      end
    end
  end
end