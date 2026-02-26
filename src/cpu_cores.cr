module PrismatIQ
  # Cross-platform CPU core detection for Linux, macOS, FreeBSD
  module CPU
    def self.cores : Int32
      # 1) Try ENV override
      if ENV["PRISMATIQ_THREADS"]?
        return ENV["PRISMATIQ_THREADS"].to_i
      end

      # 2) Platform-specific probes
      begin
        if File.exists? "/proc/cpuinfo"
          # Linux-like
          count = 0
          File.read("/proc/cpuinfo").each_line do |l|
            count += 1 if l.starts_with?("processor\t:")
          end
          return count if count > 0
        end
      rescue
      end

      begin
        # macOS: sysctl -n hw.ncpu
        begin
          begin
            out = (`sysctl -n hw.ncpu`)
          rescue ex : Exception
            out = nil
            STDERR.puts "CPU.cores: sysctl probe failed: #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
          end
          if out && out.size > 0
            n = out.to_i
            return n if n > 0
          end
        rescue ex : Exception
          STDERR.puts "CPU.cores: unexpected exception during sysctl probe: #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
        end
      rescue
      end

      begin
        # FreeBSD: sysctl -n hw.ncpu
        begin
          begin
            out = (`sysctl -n hw.ncpu`)
          rescue ex : Exception
            out = nil
            STDERR.puts "CPU.cores: sysctl probe failed (freebsd/path): #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
          end
          if out && out.size > 0
            n = out.to_i
            return n if n > 0
          end
        rescue ex : Exception
          STDERR.puts "CPU.cores: unexpected exception during sysctl probe (freebsd): #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
        end
      rescue
      end

      # Fallback
      4
    end

    # Try to probe L2 cache size in bytes. Returns nil when unknown.
    def self.l2_cache_bytes : Int32?
      # 1) macOS sysctl
      begin
        begin
          begin
            out = (`sysctl -n hw.l2cachesize`)
          rescue ex : Exception
            out = nil
            STDERR.puts "CPU.l2_cache_bytes: sysctl probe failed: #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
          end
          if out && out.size > 0
            n = out.to_i
            return n if n > 0
          end
        rescue ex : Exception
          STDERR.puts "CPU.l2_cache_bytes: unexpected exception during sysctl probe: #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
        end
      rescue
      end

      # 2) Linux sysfs probing: look for level=2 cache size under cpu0
      begin
        base = "/sys/devices/system/cpu/cpu0/cache"
        if File.exists?(base)
          Dir.entries(base).each do |entry|
            next unless entry.starts_with?("index")
            level_file = File.join(base, entry, "level")
            size_file = File.join(base, entry, "size")
            next unless File.exists?(level_file) && File.exists?(size_file)
            level = File.read(level_file).strip.to_i rescue 0
            if level == 2
              # size string like "256K"
              s = File.read(size_file).strip rescue ""
              if s.ends_with?("K")
                return (s[0...-1].to_i * 1024)
              elsif s.ends_with?("M")
                return (s[0...-1].to_i * 1024 * 1024)
              end
            end
          end
        end
      rescue
      end

      nil
    end
  end
end
