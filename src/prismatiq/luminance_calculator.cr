module PrismatIQ
  module LuminanceCalculator
    def self.relative_luminance(rgb : RGB) : Float64
      r = rgb.r / 255.0
      g = rgb.g / 255.0
      b = rgb.b / 255.0

      r = r <= 0.03928 ? r / 12.92 : ((r + 0.055) / 1.055) ** 2.4
      g = g <= 0.03928 ? g / 12.92 : ((g + 0.055) / 1.055) ** 2.4
      b = b <= 0.03928 ? b / 12.92 : ((b + 0.055) / 1.055) ** 2.4

      0.2126 * r + 0.7152 * g + 0.0722 * b
    end

    def self.relative_luminance_components(r : Int32, g : Int32, b : Int32) : Float64
      relative_luminance(RGB.new(r, g, b))
    end
  end
end
