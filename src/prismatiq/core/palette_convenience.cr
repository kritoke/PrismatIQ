require "./palette_extractor"
require "../types"
require "../options"
require "../config"
require "../utils/histogram_processor"

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
            @config.log_debug "get_palette_channel: #{ex.class}: #{ex.message}"
            ch.send([] of RGB)
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

        if palette.empty?
          return {[] of PaletteEntry, 0}
        end

        histo = build_histogram(pixels, width, height, options)
        total_pixels = histo.sum.to_i32

        entries = build_palette_entries(palette, histo, total_pixels)
        {entries, total_pixels.to_i32}
      end

      def get_palette_color_thief(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default) : Array(String)
        extractor = PaletteExtractor.new(@config)
        palette = extractor.extract_from_buffer(pixels, width, height, options)
        palette.map(&.to_hex)
      end

      # Private: Common pattern for single-color extraction from any source.
      private def extract_single_color(&block : -> Array(RGB)) : RGB?
        begin
          block.call.first?
        rescue ex : Exception
          @config.log_debug "extract_single_color: #{ex.class}: #{ex.message}"
          nil
        end
      end

      def get_color_from_path(path : String) : RGB?
        extract_single_color do
          options = Options.new(color_count: 1)
          PaletteExtractor.new(@config).extract_from_path(path, options)
        end
      end

      def get_color_from_io(io : IO) : RGB?
        extract_single_color do
          options = Options.new(color_count: 1)
          PaletteExtractor.new(@config).extract_from_io(io, options)
        end
      end

      def get_color(img : CrImage::Image) : RGB?
        extract_single_color do
          options = Options.new(color_count: 1)
          PaletteExtractor.new(@config).extract_from_image(img, options)
        end
      end

      private def build_histogram(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options) : Array(UInt32)
        histo = Array(UInt32).new(Constants::HISTOGRAM_SIZE, 0_u32)
        step = options.quality < 1 ? 1 : options.quality
        Utils::HistogramProcessor.process_pixel_range(pixels, width, 0, height, step, options.alpha_threshold, histo)
        histo
      end

      private def build_palette_entries(palette : Array(RGB), histo : Array(UInt32), total_pixels : Int32) : Array(PaletteEntry)
        return [] of PaletteEntry if total_pixels == 0

        palette.map do |rgb|
          y, i, q = YIQConverter.quantize_from_rgb(rgb.r, rgb.g, rgb.b)
          idx = YIQConverter.to_index(y, i, q)
          count = (histo[idx]? || 0_u32).to_i32
          percent = total_pixels > 0 ? count.to_f64 / total_pixels.to_f64 : 0.0
          PaletteEntry.new(rgb, count, percent)
        end
      end
    end
  end
end
