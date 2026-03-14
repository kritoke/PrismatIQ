require "./palette_extractor"
require "../types"
require "../options"
require "../config"

module PrismatIQ
  module Core
    class PaletteConvenience
      def initialize(@config : Config = Config.default)
      end

      def get_palette_channel(path : String, options : Options = Options.default) : Channel(Array(RGB))
        ch = Channel(Array(RGB)).new(1)
        spawn do
          begin
            extractor = PaletteExtractor.new(@config)
            palette = extractor.extract_from_path(path, options)
            ch.send(palette)
          rescue ex : Exception
            ch.send([RGB.new(0, 0, 0)])
          ensure
            ch.close
          end
        end
        ch
      end

      def get_palette_with_stats(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default) : Tuple(Array(PaletteEntry), Int32)
        return {[] of PaletteEntry, 0} if width <= 0 || height <= 0
        return {[] of PaletteEntry, 0} if pixels.size < width.to_i64 * height.to_i64 * 4

        extractor = PaletteExtractor.new(@config)
        palette = extractor.extract_from_buffer(pixels, width, height, options)

        if palette.empty? || (palette.size == 1 && palette[0] == RGB.new(0, 0, 0))
          return {[] of PaletteEntry, 0}
        end

        histo = build_histogram(pixels, width, height, options)
        total_pixels = histo.sum

        entries = build_palette_entries(palette, histo, total_pixels)
        {entries, total_pixels.to_i32}
      end

      def get_palette_color_thief(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default) : Array(String)
        extractor = PaletteExtractor.new(@config)
        palette = extractor.extract_from_buffer(pixels, width, height, options)
        palette.map(&.to_hex)
      end

      def get_color_from_path(path : String) : RGB
        options = Options.new(color_count: 1)
        extractor = PaletteExtractor.new(@config)
        palette = extractor.extract_from_path(path, options)
        palette.first? || RGB.new(0, 0, 0)
      end

      def get_color_from_io(io : IO) : RGB
        options = Options.new(color_count: 1)
        extractor = PaletteExtractor.new(@config)
        palette = extractor.extract_from_io(io, options)
        palette.first? || RGB.new(0, 0, 0)
      end

      def get_color(img) : RGB
        options = Options.new(color_count: 1)
        if img.is_a?(CrImage::Image)
          extractor = PaletteExtractor.new(@config)
          palette = extractor.extract_from_image(img, options)
          palette.first? || RGB.new(0, 0, 0)
        else
          begin
            read_img = CrImage.read(img)
            extractor = PaletteExtractor.new(@config)
            palette = extractor.extract_from_image(read_img.as(CrImage::Image), options)
            palette.first? || RGB.new(0, 0, 0)
          rescue ex : Exception
            RGB.new(0, 0, 0)
          end
        end
      end

      private def build_histogram(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options) : Array(Int32)
        histo = Array(Int32).new(Constants::HISTOGRAM_SIZE, 0)
        step = options.quality < 1 ? 1 : options.quality
        alpha_threshold = options.alpha_threshold

        y_coord = 0
        while y_coord < height
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
              histo[VBox.to_index(y, i, q)] += 1
            end

            x_coord += step
          end
          y_coord += step
        end

        histo
      end

      private def build_palette_entries(palette : Array(RGB), histo : Array(Int32), total_pixels : Int32) : Array(PaletteEntry)
        return [] of PaletteEntry if total_pixels == 0

        palette.map do |rgb|
          y, i, q = YIQConverter.quantize_from_rgb(rgb.r, rgb.g, rgb.b)
          idx = YIQConverter.to_index(y, i, q)
          count = histo[idx]? || 0
          percent = total_pixels > 0 ? count.to_f64 / total_pixels.to_f64 : 0.0
          PaletteEntry.new(rgb, count, percent)
        end
      end
    end
  end
end
