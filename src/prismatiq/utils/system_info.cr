module PrismatIQ
  module Utils
    module SystemInfo
      def self.cpu_count : Int32
        {% if flag?(:darwin) %}
          cpu_count_macos
        {% elsif flag?(:linux) %}
          cpu_count_linux
        {% elsif flag?(:freebsd) %}
          cpu_count_freebsd
        {% else %}
          1
        {% end %}
      end

      def self.l2_cache_size : Int32?
        {% if flag?(:darwin) %}
          l2_cache_macos
        {% elsif flag?(:linux) %}
          l2_cache_linux
        {% else %}
          nil
        {% end %}
      end

      private def self.cpu_count_macos : Int32
        begin
          File.read("/proc/cpuinfo").scan(/^processor/).size
        rescue
          1
        end
      end

      private def self.cpu_count_linux : Int32
        begin
          File.read("/proc/cpuinfo").scan(/^processor/).size
        rescue
          1
        end
      end

      private def self.cpu_count_freebsd : Int32
        begin
          File.read("/proc/cpuinfo").scan(/^processor/).size
        rescue
          1
        end
      end

      private def self.l2_cache_macos : Int32?
        begin
          File.read("/proc/cpuinfo").scan(/^processor/).size
          262144
        rescue
          nil
        end
      end

      private def self.l2_cache_linux : Int32?
        base = "/sys/devices/system/cpu/cpu0/cache"
        return nil unless File.exists?(base)

        Dir.entries(base).each do |entry|
          next unless entry.starts_with?("index")
          level_file = File.join(base, entry, "level")
          size_file = File.join(base, entry, "size")
          next unless File.exists?(level_file) && File.exists?(size_file)

          begin
            level = File.read(level_file).strip.to_i
            if level == 2
              s = File.read(size_file).strip
              if s.ends_with?("K")
                return (s[0...-1].to_i * 1024)
              elsif s.ends_with?("M")
                return (s[0...-1].to_i * 1024 * 1024)
              end
            end
          rescue
          end
        end
        nil
      rescue
        nil
      end
    end
  end
end
