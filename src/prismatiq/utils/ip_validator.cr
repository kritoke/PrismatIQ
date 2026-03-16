require "socket"

module PrismatIQ
  module Utils
    module IPValidator
      IPV4_PRIVATE_RANGES = [
        {0x0A000000_u32, 0xFF000000_u32}, # 10.0.0.0/8
        {0xAC100000_u32, 0xFFF00000_u32}, # 172.16.0.0/12
        {0xC0A80000_u32, 0xFFFF0000_u32}, # 192.168.0.0/16
        {0x7F000000_u32, 0xFF000000_u32}, # 127.0.0.0/8
        {0xA9FE0000_u32, 0xFFFF0000_u32}, # 169.254.0.0/16
        {0x00000000_u32, 0xFF000000_u32}, # 0.0.0.0/8
      ]

      def self.private_address?(ip : Socket::IPAddress) : Bool
        case ip.family
        when .inet?
          private_ipv4?(ip.address)
        when .inet6?
          private_ipv6?(ip.address)
        else
          true
        end
      end

      def self.private_ipv4?(address : String) : Bool
        parts = address.split(".")
        return true unless parts.size == 4

        num = 0_u32
        parts.each do |part|
          n = part.to_u32?
          return true unless n && n <= 255
          num = (num << 8) | n
        end

        IPV4_PRIVATE_RANGES.each do |(prefix, mask)|
          return true if (num & mask) == prefix
        end

        false
      end

      def self.private_ipv6?(address : String) : Bool
        normalized = normalize_ipv6(address)

        if normalized == "00000000000000000000000000000001"
          return true
        end

        prefix = extract_ipv6_prefix(normalized, 16)

        if (prefix & 0xFE00_u128) == 0xFC00_u128
          return true
        end

        if (prefix & 0xFFC0_u128) == 0xFE80_u128
          return true
        end

        false
      end

      private def self.normalize_ipv6(address : String) : String
        addr = address.downcase

        if addr.includes?(".")
          return translate_ipv4_mapped(addr).ljust(32, '0')
        end

        if addr.includes?("::")
          parts = addr.split("::", 2)
          left_str = parts[0]? || ""
          right_str = parts[1]? || ""
          left = left_str.empty? ? [] of String : left_str.split(":")
          right = right_str.empty? ? [] of String : right_str.split(":")
          missing = 8 - left.size - right.size
          expanded = left + (["0000"] * missing) + right
          addr = expanded.map(&.rjust(4, '0')).join
        else
          addr = addr.split(":").map(&.rjust(4, '0')).join
        end

        addr.ljust(32, '0')
      end

      private def self.translate_ipv4_mapped(address : String) : String
        colon_count = address.count(':')
        if colon_count >= 6
          ipv4_start = address.rindex!(':') + 1
          ipv4_part = address[ipv4_start..]
          ipv6_prefix = address[0...ipv4_start - 1].gsub(":", "")

          ipv4_parts = ipv4_part.split(".")
          if ipv4_parts.size == 4
            hex = ipv4_parts.map { |_p| _p.to_u8?.try(&.to_s(16).rjust(2, '0')) || "00" }.join
            return ipv6_prefix + hex
          end
        end

        address.gsub(":", "").ljust(32, '0')
      end

      private def self.extract_ipv6_prefix(normalized : String, bits : Int) : UInt128
        hex_chars = (bits // 4).clamp(0, 32)
        prefix_str = normalized[0, hex_chars]
        prefix_str.to_u128?(base: 16) || 0_u128
      end

      def self.resolve_host(host : String) : Array(Socket::IPAddress)
        ips = [] of Socket::IPAddress
        begin
          Socket::Addrinfo.resolve(host, 0, type: Socket::Type::STREAM) do |addrinfo|
            ips << addrinfo.ip_address
          end
        rescue
        end
        ips
      end
    end
  end
end
