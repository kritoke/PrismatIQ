require "../algorithm/color_space"

module PrismatIQ
  module Utils
    module HistogramProcessor
      @[AlwaysInline]
      def self.process_pixel_range(pixels : Slice(UInt8), width : Int32, start_row : Int32, end_row : Int32, step : Int32, alpha_threshold : UInt8, histo : Array(UInt32)) : Int32
        count = 0
        y_coord = start_row
        while y_coord < end_row
          x_coord = 0
          while x_coord < width
            idx = (y_coord * width + x_coord) * 4
            break if idx + 3 >= pixels.size

            a = pixels[idx + 3]
            if a >= alpha_threshold
              r = pixels[idx].to_i
              g = pixels[idx + 1].to_i
              b = pixels[idx + 2].to_i
              y, i, q = YIQConverter.quantize_from_rgb(r, g, b)
              histo[VBox.to_index(y, i, q)] += 1_u32
              count += 1
            end

            x_coord += step
          end
          y_coord += step
        end
        count
      end
    end
  end
end
