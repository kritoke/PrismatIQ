require "./prismatiq/utils/system_info"

module PrismatIQ
  module CPU
    def self.cores(config : Config? = nil) : Int32
      # Use the new secure SystemInfo module
      Utils::SystemInfo.cpu_count
    end

    def self.l2_cache_bytes(config : Config? = nil) : Int32?
      # Use the new secure SystemInfo module
      Utils::SystemInfo.l2_cache_size
    end
  end
end
