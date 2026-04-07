require "json"
require "yaml"

module PrismatIQ
  struct RGB
    getter r : Int32
    getter g : Int32
    getter b : Int32

    def initialize(@r : Int32, @g : Int32, @b : Int32)
    end

    def to_hex : String
      "#%02x%02x%02x" % [@r, @g, @b]
    end

    def self.from_hex(hex : String) : RGB
      hex = hex.lchop('#')
      case hex.size
      when 3
        r = hex[0].to_s * 2
        g = hex[1].to_s * 2
        b = hex[2].to_s * 2
        new(r.to_i(16), g.to_i(16), b.to_i(16))
      when 6
        begin
          new(hex[0, 2].to_i(16), hex[2, 2].to_i(16), hex[4, 2].to_i(16))
        rescue ex : ArgumentError
          raise ValidationError.new("Invalid hex color characters: #{hex}")
        end
      else
        raise ValidationError.new("Invalid hex color: #{hex}")
      end
    end

    def self.from_rgb_string(value : String) : RGB
      inner = value.gsub(/^rgba?\(/, "").gsub(/\)$/, "")
      parts = inner.split(',').map(&.strip)
      raise ValidationError.new("Invalid rgb string: #{value}") unless parts.size >= 3

      r = parse_rgb_component(parts[0])
      g = parse_rgb_component(parts[1])
      b = parse_rgb_component(parts[2])
      raise ValidationError.new("Invalid rgb string: #{value}") unless r && g && b
      new(r, g, b)
    end

    private def self.parse_rgb_component(value : String) : Int32?
      value = value.strip
      if value.ends_with?("%")
        percent = value.rchop('%').to_f?
        return ((percent / 100.0) * 255.0).round.to_i.clamp(0, 255) if percent
      end
      value.to_i?.try(&.clamp(0, 255))
    end

    def distance_to(other : RGB) : Float64
      Math.sqrt((@r - other.r)**2 + (@g - other.g)**2 + (@b - other.b)**2)
    end

    def to_json(builder : JSON::Builder)
      builder.string(to_hex)
    end

    def self.new(pull : JSON::PullParser)
      from_hex(pull.read_string)
    end

    def to_yaml(yaml : YAML::Nodes::Builder)
      yaml.scalar to_hex
    end

    def self.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
      unless node.is_a?(YAML::Nodes::Scalar)
        raise ValidationError.new("Expected scalar for RGB")
      end
      from_hex(node.value)
    end
  end
end
