require "crtemp"
require "crtemp/constants"
HAVE_CRTEMP = true

module PrismatIQ
  module TempfileHelper
    lib LibC
      fun mkstemp(template : Pointer(UInt8)) : Int32
      fun write(fd : Int32, buf : Pointer(Void), count : UInt64) : Int64
      fun close(fd : Int32) : Int32
    end

    # Create a secure temp file and write the provided slice bytes.
    # On Windows use a randomized-filename fallback; on Unix use mkstemp.
    # Prefer using the installed crtemp shard when available. Dir.mktmpdir
    # provides an atomic directory creation helper; we'll use it to create a
    # secure directory and then create a file inside it atomically.
    # Returns nil if data exceeds 100MB limit (aligned with Validation::MAX_FILE_SIZE).
    MAX_DATA_SIZE = 100 * 1024 * 1024_i64

    def self.create_and_write(prefix : String, data : Slice(UInt8)) : String?
      return if data.size > MAX_DATA_SIZE

      result = try_crtemp_approach(prefix, data)
      return result if result

      {% if flag?(:windows) %}
        try_windows_fallback(prefix, data)
      {% else %}
        try_unix_mkstemp(prefix, data)
      {% end %}
    end

    private def self.try_crtemp_approach(prefix : String, data : Slice(UInt8)) : String?
      return unless HAVE_CRTEMP

      begin
        Dir.mktmpdir do |dir|
          base = dir.is_a?(Crtemp) ? dir.path : dir.to_s
          safe_prefix = prefix.size > CrtempConstants::MAX_PREFIX_LENGTH ? prefix[0, CrtempConstants::MAX_PREFIX_LENGTH] : prefix

          if dir.is_a?(Crtemp)
            result = dir.create_tempfile_result(safe_prefix, data)
            if result.success?
              next result.value!
            end
          end

          path = "#{base}/#{prefix}#{Process.pid}_#{Time.local.to_unix}.bin"
          write_buffer_to_file(path, data)
          path
        end
      rescue ex : Exception
        STDERR.puts "PrismatIQ: try_crtemp_approach failed (#{ex.class.name}): #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
      end
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

    private def self.try_windows_fallback(prefix : String, data : Slice(UInt8)) : String?
      tmp_dir = ENV["TMPDIR"]? || ENV["TEMP"]? || "."
      tries = 0
      while tries < 16
        rnd = Random.new.rand(0_u32..0xFFFF_FFFF_u32)
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
          STDERR.puts "PrismatIQ: try_windows_fallback failed (#{ex.class.name}): #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
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

      idx = 0
      String.build do |str|
        while buf[idx] != 0
          str << buf[idx].chr
          idx += 1
        end
      end
    end

    # Create a tempfile, write data, yield the path to the provided block and
    # ensure the tempfile is removed afterwards. Returns the block's result or
    # nil if tempfile creation failed.
    def self.with_tempfile(prefix : String, data : Slice(UInt8), &)
      path = create_and_write(prefix, data)
      return unless path

      begin
        yield(path)
      ensure
        begin
          File.delete(path) if path && File.exists?(path)
        rescue ex : Exception
          STDERR.puts "PrismatIQ: with_tempfile cleanup failed (#{ex.class.name}): #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
        end
      end
    end
  end
end
