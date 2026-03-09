module PrismatIQ
  module Utils
    module SystemInfo
      def self.cpu_count
        # Check environment variable override first
        if env_count = ENV["PRISMATIQ_THREADS"]?
          return env_count.to_i32
        end

        # Use Crystal's built-in CPU count detection
        # This is secure and doesn't use shell commands
        count = System.cpu_count || 1_i64
        result = count.is_a?(Int64) ? count.to_i32 : count
        result > 0 ? result : 1_i32
      rescue
        1_i32
      end

      def self.l2_cache_size : Int32?
        {% if flag?(:linux) %}
          l2_cache_linux
        {% else %}
          nil
        {% end %}
      rescue
        nil
      end

      {% if flag?(:linux) %}
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
      {% end %}
    end
  end
end
