require "crtemp"
require "crtemp/constants"

module PrismatIQ
  module TempfileHelper
    lib LibC
      fun mkstemp(template : Pointer(UInt8)) : Int32
      fun write(fd : Int32, buf : Pointer(Void), count : UInt64) : Int64
      fun close(fd : Int32) : Int32
    end

    MAX_DATA_SIZE = 100 * 1024 * 1024_i64

    def self.create_and_write(prefix : String, data : Slice(UInt8), debug : Bool = false) : String?
      return if data.size > MAX_DATA_SIZE

      {% if flag?(:windows) %}
        try_windows_fallback(prefix, data, debug)
      {% else %}
        try_unix_mkstemp(prefix, data)
      {% end %}
    rescue ex : Exception
      STDERR.puts "PrismatIQ: create_and_write failed (#{ex.class.name}): #{ex.message}" if debug
      nil
    end

    private def self.write_buffer_to_file(path : String, data : Slice(UInt8))
      File.open(path, "w") do |file|
        buffer = Bytes.new(data.size)
        data.copy_to(buffer)
        file.write(buffer)
        file.flush
      end
    end

    private def self.try_windows_fallback(prefix : String, data : Slice(UInt8), debug : Bool = false) : String?
      tmp_dir = ENV["TMPDIR"]? || ENV["TEMP"]? || "."
      tries = 0
      while tries < 16
        rnd = Random::Secure.hex(4)
        path = "#{tmp_dir}/#{prefix}#{Process.pid}_#{Time.local.to_unix}_#{rnd}.tmp"
        begin
          File.open(path, "w", exclusive: true) do |file|
            buffer = Bytes.new(data.size)
            data.copy_to(buffer)
            file.write(buffer)
            file.flush
          end
          return path
        rescue File::AlreadyExistsError
          next
        rescue ex : Exception
          STDERR.puts "PrismatIQ: try_windows_fallback failed (#{ex.class.name}): #{ex.message}" if debug
        end
        tries += 1
      end
      nil
    end

    private def self.try_unix_mkstemp(prefix : String, data : Slice(UInt8)) : String?
      tmp_dir = ENV["TMPDIR"]? || "/tmp"
      tmpl = "#{tmp_dir}/#{prefix}XXXXXX".dup

      tmpl_bytes = tmpl.to_slice
      buf = Bytes.new(tmpl_bytes.size + 1)
      tmpl_bytes.copy_to(buf)
      buf[tmpl_bytes.size] = 0

      fd = LibC.mkstemp(buf.to_unsafe)
      return if fd < 0

      path_str = String.build do |str|
        idx = 0
        while buf[idx] != 0
          str << buf[idx].chr
          idx += 1
        end
      end

      begin
        File.chmod(path_str, 0o600)
      rescue
      end

      begin
        total = data.size
        written = 0
        while written < total
          ptr = data.to_unsafe + written
          left = (total - written).to_u64
          w = LibC.write(fd, ptr.as(Pointer(Void)), left)
          return if w <= 0
          written += w.to_i
        end
      ensure
        LibC.close(fd)
      end

      path_str
    end

    def self.with_tempfile(prefix : String, data : Slice(UInt8), debug : Bool = false, &)
      path = create_and_write(prefix, data, debug)
      return unless path

      begin
        yield(path)
      ensure
        begin
          File.delete(path) if path && File.exists?(path)
        rescue ex : Exception
          STDERR.puts "PrismatIQ: with_tempfile cleanup failed (#{ex.class.name}): #{ex.message}" if debug
        end
      end
    end
  end
end
