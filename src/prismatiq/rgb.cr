require "json"
require "yaml"

module PrismatIQ
  struct RGB
    include JSON::Serializable
    include YAML::Serializable

    getter r : Int32
    getter g : Int32
    getter b : Int32

    def initialize(@r : Int32, @g : Int32, @b : Int32)
    end

    def to_hex : String
      String.build do |str|
        str << '#'
        str << @r.to_s(16).rjust(2, '0')
        str << @g.to_s(16).rjust(2, '0')
        str << @b.to_s(16).rjust(2, '0')
      end
    end

    def self.from_hex(hex : String) : RGB
      hex = hex.lchop('#')
      raise ValidationError.new("Invalid hex color: #{hex}") unless hex.size == 6
      begin
        r = hex[0, 2].to_i(16)
        g = hex[2, 2].to_i(16)
        b = hex[4, 2].to_i(16)
        new(r, g, b)
      rescue
        raise ValidationError.new("Invalid hex color characters: #{hex}")
      end
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
