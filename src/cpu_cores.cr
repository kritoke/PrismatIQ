require "./prismatiq/utils/system_info"

module PrismatIQ
  module CPU
    def self.cores : Int32
      Utils::SystemInfo.cpu_count
    end

    def self.l2_cache_bytes : Int32?
      Utils::SystemInfo.l2_cache_size
    end
  end
end
