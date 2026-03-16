require "xml"
require "math"

module PrismatIQ
  module SVGColorExtractor
    COLOR_ATTRIBUTES = ["fill", "stroke", "stop-color", "flood-color", "lighting-color", "color"]

    SVG_NAMED_COLORS = {
      "black"                => {0, 0, 0},
      "white"                => {255, 255, 255},
      "red"                  => {255, 0, 0},
      "green"                => {0, 128, 0},
      "lime"                 => {0, 255, 0},
      "blue"                 => {0, 0, 255},
      "yellow"               => {255, 255, 0},
      "cyan"                 => {0, 255, 255},
      "aqua"                 => {0, 255, 255},
      "magenta"              => {255, 0, 255},
      "fuchsia"              => {255, 0, 255},
      "silver"               => {192, 192, 192},
      "gray"                 => {128, 128, 128},
      "grey"                 => {128, 128, 128},
      "maroon"               => {128, 0, 0},
      "olive"                => {128, 128, 0},
      "purple"               => {128, 0, 128},
      "teal"                 => {0, 128, 128},
      "navy"                 => {0, 0, 128},
      "orange"               => {255, 165, 0},
      "pink"                 => {255, 192, 203},
      "coral"                => {255, 127, 80},
      "salmon"               => {250, 128, 114},
      "tomato"               => {255, 99, 71},
      "gold"                 => {255, 215, 0},
      "violet"               => {238, 130, 238},
      "indigo"               => {75, 0, 130},
      "crimson"              => {220, 20, 60},
      "chocolate"            => {210, 105, 30},
      "tan"                  => {210, 180, 140},
      "sienna"               => {160, 82, 45},
      "brown"                => {165, 42, 42},
      "beige"                => {245, 245, 220},
      "ivory"                => {255, 255, 240},
      "wheat"                => {245, 222, 179},
      "linen"                => {250, 240, 230},
      "lavender"             => {230, 230, 250},
      "plum"                 => {221, 160, 221},
      "orchid"               => {218, 112, 214},
      "thistle"              => {216, 191, 216},
      "azure"                => {240, 255, 255},
      "aliceblue"            => {240, 248, 255},
      "mintcream"            => {245, 255, 250},
      "honeydew"             => {240, 255, 240},
      "snow"                 => {255, 250, 250},
      "seashell"             => {255, 245, 238},
      "floralwhite"          => {255, 250, 240},
      "ghostwhite"           => {248, 248, 255},
      "whitesmoke"           => {245, 245, 245},
      "gainsboro"            => {220, 220, 220},
      "lightgray"            => {211, 211, 211},
      "lightgrey"            => {211, 211, 211},
      "darkgray"             => {169, 169, 169},
      "darkgrey"             => {169, 169, 169},
      "dimgray"              => {105, 105, 105},
      "dimgrey"              => {105, 105, 105},
      "lightslategray"       => {119, 136, 153},
      "lightslategrey"       => {119, 136, 153},
      "slategray"            => {112, 128, 144},
      "slategrey"            => {112, 128, 144},
      "darkslategray"        => {47, 79, 79},
      "darkslategrey"        => {47, 79, 79},
      "lightcoral"           => {240, 128, 128},
      "indianred"            => {205, 92, 92},
      "firebrick"            => {178, 34, 34},
      "darkred"              => {139, 0, 0},
      "lightsalmon"          => {255, 160, 122},
      "darksalmon"           => {233, 150, 122},
      "orangered"            => {255, 69, 0},
      "darkorange"           => {255, 140, 0},
      "lightgoldenrodyellow" => {250, 250, 210},
      "lemonchiffon"         => {255, 250, 205},
      "papayawhip"           => {255, 239, 213},
      "moccasin"             => {255, 228, 181},
      "peachpuff"            => {255, 218, 185},
      "palegoldenrod"        => {238, 232, 170},
      "khaki"                => {240, 230, 140},
      "darkkhaki"            => {189, 183, 107},
      "yellowgreen"          => {154, 205, 50},
      "darkolivegreen"       => {85, 107, 47},
      "olivedrab"            => {107, 142, 35},
      "lawngreen"            => {124, 252, 0},
      "chartreuse"           => {127, 255, 0},
      "greenyellow"          => {173, 255, 47},
      "darkgreen"            => {0, 100, 0},
      "forestgreen"          => {34, 139, 34},
      "seagreen"             => {46, 139, 87},
      "mediumseagreen"       => {60, 179, 113},
      "springgreen"          => {0, 255, 127},
      "mediumspringgreen"    => {0, 250, 154},
      "lightgreen"           => {144, 238, 144},
      "palegreen"            => {152, 251, 152},
      "darkseagreen"         => {143, 188, 143},
      "mediumaquamarine"     => {102, 205, 170},
      "aquamarine"           => {127, 255, 212},
      "lightseagreen"        => {32, 178, 170},
      "darkcyan"             => {0, 139, 139},
      "lightcyan"            => {224, 255, 255},
      "paleturquoise"        => {175, 238, 238},
      "turquoise"            => {64, 224, 208},
      "mediumturquoise"      => {72, 209, 204},
      "darkturquoise"        => {0, 206, 209},
      "cadetblue"            => {95, 158, 160},
      "steelblue"            => {70, 130, 180},
      "lightsteelblue"       => {176, 196, 222},
      "powderblue"           => {176, 224, 230},
      "lightblue"            => {173, 216, 230},
      "skyblue"              => {135, 206, 235},
      "lightskyblue"         => {135, 206, 250},
      "deepskyblue"          => {0, 191, 255},
      "dodgerblue"           => {30, 144, 255},
      "cornflowerblue"       => {100, 149, 237},
      "mediumslateblue"      => {123, 104, 238},
      "royalblue"            => {65, 105, 225},
      "mediumblue"           => {0, 0, 205},
      "darkblue"             => {0, 0, 139},
      "midnightblue"         => {25, 25, 112},
      "slateblue"            => {106, 90, 205},
      "darkslateblue"        => {72, 61, 139},
      "blueviolet"           => {138, 43, 226},
      "darkviolet"           => {148, 0, 211},
      "darkorchid"           => {153, 50, 204},
      "darkmagenta"          => {139, 0, 139},
      "mediumpurple"         => {147, 112, 219},
      "mediumorchid"         => {186, 85, 211},
      "mediumvioletred"      => {199, 21, 133},
      "palevioletred"        => {219, 112, 147},
      "deeppink"             => {255, 20, 147},
      "hotpink"              => {255, 105, 180},
      "lightpink"            => {255, 182, 193},
      "rosybrown"            => {188, 143, 143},
      "sandybrown"           => {244, 164, 96},
      "goldenrod"            => {218, 165, 32},
      "darkgoldenrod"        => {184, 134, 11},
      "peru"                 => {205, 133, 63},
      "saddlebrown"          => {139, 69, 19},
      "burlywood"            => {222, 184, 135},
      "bisque"               => {255, 228, 196},
      "navajowhite"          => {255, 222, 173},
      "blanchedalmond"       => {255, 235, 205},
      "cornsilk"             => {255, 248, 220},
      "antiquewhite"         => {250, 235, 215},
      "mistyrose"            => {255, 228, 225},
      "lavenderblush"        => {255, 240, 245},
    }

    def self.extract_colors(source : String | IO) : Array(RGB)
      svg_content = source.is_a?(String) ? source : source.gets_to_end
      doc = XML.parse(svg_content)

      colors = [] of RGB
      color_values = Set(String).new

      if root = doc.root
        extract_colors_recursive(root, colors, color_values)
      end

      colors
    end

    private def self.extract_colors_recursive(node : XML::Node, colors : Array(RGB), seen : Set(String))
      if node.element?
        COLOR_ATTRIBUTES.each do |attr|
          if value = node[attr]?
            value = value.strip
            next if value.empty? || value == "none" || value == "inherit"
            next if seen.includes?(value)

            if rgb = parse_color(value)
              hex_key = rgb.to_hex
              unless seen.includes?(hex_key)
                colors << rgb
                seen << hex_key
              end
              seen << value
            end
          end
        end
      end

      node.children.each do |child|
        extract_colors_recursive(child, colors, seen)
      end
    end

    def self.parse_color(value : String) : RGB?
      value = value.strip.downcase

      nil if value.empty? || value == "none" || value == "inherit" || value == "transparent"

      if value == "currentcolor"
        return RGB.new(0, 0, 0)
      end

      if value.starts_with?("#")
        return parse_hex(value)
      end

      if value.starts_with?("rgb(") || value.starts_with?("rgba(")
        return parse_rgb(value)
      end

      if value.starts_with?("hsl(") || value.starts_with?("hsla(")
        return parse_hsl(value)
      end

      if rgb_tuple = SVG_NAMED_COLORS[value]?
        return RGB.new(rgb_tuple[0], rgb_tuple[1], rgb_tuple[2])
      end

      nil
    end

    private def self.parse_hex(value : String) : RGB?
      hex = value.lchop('#')

      case hex.size
      when 3
        r = hex[0].to_s * 2
        g = hex[1].to_s * 2
        b = hex[2].to_s * 2
        RGB.new(r.to_i(16), g.to_i(16), b.to_i(16))
      when 6
        RGB.new(hex[0, 2].to_i(16), hex[2, 2].to_i(16), hex[4, 2].to_i(16))
      when 8
        RGB.new(hex[0, 2].to_i(16), hex[2, 2].to_i(16), hex[4, 2].to_i(16))
      end
    rescue
      nil
    end

    private def self.parse_rgb(value : String) : RGB?
      inner = value.gsub(/^(rgba?|hsla?)\(/, "").gsub(/\)$/, "")

      parts = inner.split(',').map(&.strip)
      return unless parts.size >= 3

      r = parse_rgb_component(parts[0])
      g = parse_rgb_component(parts[1])
      b = parse_rgb_component(parts[2])

      return unless r && g && b

      RGB.new(r, g, b)
    rescue
      nil
    end

    private def self.parse_rgb_component(value : String) : Int32?
      value = value.strip

      if value.ends_with?("%")
        percent = value.rchop('%').to_f?
        return ((percent / 100.0) * 255.0).round.to_i.clamp(0, 255) if percent
      end

      value.to_i?.try(&.clamp(0, 255))
    end

    private def self.parse_hsl(value : String) : RGB?
      inner = value.gsub(/^(rgba?|hsla?)\(/, "").gsub(/\)$/, "")

      parts = inner.split(',').map(&.strip)
      return unless parts.size >= 3

      hue_val = parse_hue(parts[0])
      sat_val = parse_percentage(parts[1])
      light_val = parse_percentage(parts[2])

      return unless hue_val && sat_val && light_val

      hsl_to_rgb(hue_val, sat_val, light_val)
    rescue
      nil
    end

    private def self.parse_hue(value : String) : Float64?
      value = value.strip
      value = value.rchop("deg") if value.ends_with?("deg")
      value = value.rchop("°") if value.ends_with?("°")
      value.to_f?
    end

    private def self.parse_percentage(value : String) : Float64?
      value = value.strip
      return unless value.ends_with?("%")
      value.rchop('%').to_f?
    end

    private def self.hsl_to_rgb(h : Float64, s : Float64, l : Float64) : RGB
      s /= 100.0
      l /= 100.0

      if s == 0
        val = (l * 255).round.to_i
        return RGB.new(val, val, val)
      end

      h = h % 360.0

      c = (1.0 - (2.0 * l - 1.0).abs) * s
      x = c * (1.0 - ((h / 60.0) % 2.0 - 1.0).abs)
      m = l - c / 2.0

      r1, g1, b1 = if h < 60.0
                     {c, x, 0.0}
                   elsif h < 120.0
                     {x, c, 0.0}
                   elsif h < 180.0
                     {0.0, c, x}
                   elsif h < 240.0
                     {0.0, x, c}
                   elsif h < 300.0
                     {x, 0.0, c}
                   else
                     {c, 0.0, x}
                   end

      r = ((r1 + m) * 255).round.to_i.clamp(0, 255)
      g = ((g1 + m) * 255).round.to_i.clamp(0, 255)
      b = ((b1 + m) * 255).round.to_i.clamp(0, 255)

      RGB.new(r, g, b)
    end

    def self.extract_from_file(path : String) : Result(Array(RGB), Error)
      unless File.exists?(path)
        return Result(Array(RGB), Error).err(Error.file_not_found(path))
      end

      content = File.read(path)
      colors = extract_colors(content)
      Result(Array(RGB), Error).ok(colors)
    rescue ex : XML::Error
      Result(Array(RGB), Error).err(Error.corrupted_image("Invalid SVG XML: #{ex.message}"))
    rescue ex : Exception
      Result(Array(RGB), Error).err(Error.corrupted_image("Failed to parse SVG: #{ex.message}"))
    end
  end
end
