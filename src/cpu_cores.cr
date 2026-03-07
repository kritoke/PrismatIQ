module PrismatIQ
  # Cross-platform CPU core detection for Linux, macOS, FreeBSD
  module CPU
    def self.cores(config : Config? = nil) : Int32
      debug = (config && config.debug) || ENV["PRISMATIQ_DEBUG"]? == "true" || ENV["PRISMATIQ_DEBUG"]? == "1"

      # 1) Try ENV override (or config override)
      if config && config.threads
        return config.threads
      elsif ENV["PRISMATIQ_THREADS"]?
        return ENV["PRISMATIQ_THREADS"].to_i
      end

      # 2) Try platform-specific probes in order
      result = try_linux_cpuinfo || try_sysctl_hw_ncpu(debug)
      return result if result > 0

      # Fallback
      4
    end

    private def self.try_linux_cpuinfo : Int32
      return 0 unless File.exists?("/proc/cpuinfo")

      count = 0
      File.read("/proc/cpuinfo").each_line do |line|
        count += 1 if line.starts_with?("processor\t:")
      end
      count
    rescue
      0
    end

    private def self.try_sysctl_hw_ncpu(debug : Bool) : Int32
      begin
        out = (`sysctl -n hw.ncpu`)
        return 0 unless out && out.size > 0

        n = out.to_i
        return n if n > 0
      rescue ex : Exception
        msg = "CPU.cores: sysctl probe failed: #{ex.message}"
        STDERR.puts msg if debug
      end
      0
    rescue ex : Exception
      msg = "CPU.cores: unexpected exception during sysctl probe: #{ex.message}"
      STDERR.puts msg if debug
      0
    end

    # Try to probe L2 cache size in bytes. Returns nil when unknown.
    def self.l2_cache_bytes(config : Config? = nil) : Int32?
      debug = (config && config.debug) || ENV["PRISMATIQ_DEBUG"]? == "true" || ENV["PRISMATIQ_DEBUG"]? == "1"

      # 1) Try macOS sysctl
      result = try_macos_l2_cache(debug)
      return result if result

      # 2) Try Linux sysfs probing
      result = try_linux_l2_cache
      return result if result

      nil
    end

    private def self.try_macos_l2_cache(debug : Bool) : Int32?
      begin
        out = (`sysctl -n hw.l2cachesize`)
        return unless out && out.size > 0

        n = out.to_i
        return n if n > 0
      rescue ex : Exception
        msg = "CPU.l2_cache_bytes: sysctl probe failed: #{ex.message}"
        STDERR.puts msg if debug
      end
      nil
    rescue ex : Exception
      msg = "CPU.l2_cache_bytes: unexpected exception during sysctl probe: #{ex.message}"
      STDERR.puts msg if debug
      nil
    end

    private def self.try_linux_l2_cache : Int32?
      base = "/sys/devices/system/cpu/cpu0/cache"
      return unless File.exists?(base)

      Dir.entries(base).each do |entry|
        next unless entry.starts_with?("index")
        level_file = File.join(base, entry, "level")
        size_file = File.join(base, entry, "size")
        next unless File.exists?(level_file) && File.exists?(size_file)

        begin
          level = File.read(level_file).strip.to_i
          if level == 2
            # size string like "256K"
            s = File.read(size_file).strip
            if s.ends_with?("K")
              return (s[0...-1].to_i * 1024)
            elsif s.ends_with?("M")
              return (s[0...-1].to_i * 1024 * 1024)
            end
          end
        rescue
          # Skip this cache entry if reading fails
        end
      end
      nil
    rescue
      nil
    end
  end
end
