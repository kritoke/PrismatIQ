require "tempdir"
HAVE_TEMPDIR = true

module PrismatIQ
  module TempfileHelper
    lib LibC
      fun mkstemp(template : Pointer(UInt8)) : Int32
      fun write(fd : Int32, buf : Pointer(Void), count : UInt64) : Int64
      fun close(fd : Int32) : Int32
    end

    # Create a secure temp file and write the provided slice bytes.
    # On Windows use a randomized-filename fallback; on Unix use mkstemp.
    # Prefer using the installed tempdir shard when available. Dir.mktmpdir
    # provides an atomic directory creation helper; we'll use it to create a
    # secure directory and then create a file inside it atomically.
    def self.create_and_write(prefix : String, data : Slice(UInt8)) : String?
      if HAVE_TEMPDIR
        # Use Dir.mktmpdir to create a secure directory and create a file inside it.
        begin
          Dir.mktmpdir do |d|
          # Dir.mktmpdir may yield either a Tempdir instance (our vendored
          # implementation) or a String path (older/other implementations).
          base = d.is_a?(Tempdir) ? d.path : d.to_s

          # If the Tempdir instance (our vendored Tempdir) is being used,
          # prefer its create_tempfile helper which uses mkstemp. Limit prefix
          # length to avoid platform filename length limits.
          safe_prefix = prefix.size > 100 ? prefix[0, 100] : prefix
          if d.is_a?(Tempdir)
            created = d.create_tempfile(safe_prefix, data)
            if created
              next created
            end
            # fall through to manual write if create_tempfile failed
          end

          path = "#{base}/#{prefix}#{Process.pid}_#{Time.local.to_unix}.bin"
          File.open(path, "w") do |f|
            # Write raw bytes using Bytes to avoid encoding issues
            b = Bytes.new(data.size)
            i = 0
            while i < data.size
              b[i] = data[i]
              i += 1
            end
            f.write(b)
            f.flush
          end
          next path
          end
        rescue ex : Exception
          STDERR.puts "PrismatIQ: tempfile via tempdir failed: #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
          return nil
        end
      end

      if {% flag?(:windows) %}
        tmp_dir = ENV["TMPDIR"]? ? ENV["TMPDIR"] : (ENV["TEMP"]? ? ENV["TEMP"] : ".")
        tries = 0
        while tries < 16
          rnd = Random.new.rand(0_u32..0xFFFF_FFFF_u32)
          path = "#{tmp_dir}/#{prefix}#{Process.pid}_#{Time.local.to_unix}_#{rnd}.tmp"
          if !File.exists?(path)
            begin
              File.open(path, "w") do |f|
                # Build a Bytes buffer and write it in one call to avoid
                # character-encoding issues when constructing a String.
                total = data.size
                b = Bytes.new(total)
                i = 0
                while i < total
                  b[i] = data[i]
                  i += 1
                end
                f.write(b)
                f.flush
              end
              return path
            rescue ex : Exception
              STDERR.puts "PrismatIQ: windows tempfile fallback failed: #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
            end
          end
          tries += 1
        end
        nil
      else
        tmp_dir = ENV["TMPDIR"]? ? ENV["TMPDIR"] : "/tmp"
        tmpl = "#{tmp_dir}/#{prefix}XXXXXX".dup

        tmpl_bytes = tmpl.to_slice
        buf = Bytes.new(tmpl_bytes.size + 1)
        i = 0
        while i < tmpl_bytes.size
          buf[i] = tmpl_bytes[i]
          i += 1
        end
        buf[i] = 0

        fd = LibC.mkstemp(buf.to_unsafe)
        if fd < 0
          return nil
        end

        total = data.size
        written = 0
        while written < total
          ptr = data.to_unsafe + written
          left = (total - written).to_u64
          w = LibC.write(fd, ptr.as(Pointer(Void)), left)
          if w <= 0
            LibC.close(fd)
            return nil
          end
          written += w.to_i
        end

        LibC.close(fd)

        idx = 0
        path = String.build do |s|
          while buf[idx] != 0
            s << buf[idx].chr
            idx += 1
          end
        end
        path
      end
    end

    # Create a tempfile, write data, yield the path to the provided block and
    # ensure the tempfile is removed afterwards. Returns the block's result or
    # nil if tempfile creation failed.
    def self.with_tempfile(prefix : String, data : Slice(UInt8))
      path = create_and_write(prefix, data)
      return nil unless path

      begin
        return yield(path)
      ensure
        begin
          File.delete(path) if path && File.exists?(path)
        rescue
          # best-effort cleanup; do not raise
        end
      end
    end
  end
end
