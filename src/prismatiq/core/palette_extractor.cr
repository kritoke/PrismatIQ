require "../types"
require "../options"
require "../config"
require "../algorithm/mmcq"
require "../algorithm/color_space"
require "../utils/histogram_processor"
require "../utils/image_loader"
require "../utils/validation"

module PrismatIQ
  module Core
    # Thread-safe palette extraction orchestrator.
    #
    # This class handles the complete palette extraction workflow from raw pixel data
    # to final dominant colors. It coordinates histogram building, quantization,
    # and result processing while maintaining thread safety.
    #
    # ## Thread Safety
    #
    # - **Stateless Design**: No shared mutable state between instances
    # - **Safe Concurrent Access**: Multiple threads can use different instances
    #   simultaneously without coordination
    # - **Config Isolation**: Each instance uses its own Config for processing
    #
    # ## Memory Optimization
    #
    # - Configurable max image dimensions via Config
    # - Sequential histogram building with bounded iteration
    #
    # ## Usage
    #
    # ```
    # extractor = PrismatIQ::Core::PaletteExtractor.new
    # palette = extractor.extract_from_path("image.jpg", options)
    # ```
    class PaletteExtractor
      include Utils::HistogramProcessor

      def initialize(@config : Config = Config.default)
      end

      # Private: Common pipeline for image-based extraction.
      # Loads image, checks dimensions, normalizes, and extracts palette.
      private def extract_from_image_source(img, options : Options) : Array(RGB)
        width = img.bounds.width.to_i32
        height = img.bounds.height.to_i32

        if width > @config.max_image_width || height > @config.max_image_height
          @config.log_debug "extract_from_image_source: dimensions #{width}x#{height} exceed max #{@config.max_image_width}x#{@config.max_image_height}"
          return [] of RGB
        end

        rgba_image = Utils::ImageLoader.normalize(img)
        do_extract_from_image_data(rgba_image, width, height, options)
      end

      def extract_from_path(path : String, options : Options) : Array(RGB)
        if @config.debug_log?
          @config.log_debug "get_palette(path): path=#{path} options=#{options.inspect}"
        end

        validation = Utils::Validation.validate_file_path(path)
        return [] of RGB if validation.err?

        img = Utils::ImageLoader.read(validation.value)
        extract_from_image_source(img, options)
      end

      def extract_from_io(io : IO, options : Options) : Array(RGB)
        img = Utils::ImageLoader.read(io)
        extract_from_image_source(img, options)
      end

      def extract_from_image(image, options : Options) : Array(RGB)
        if @config.debug_log?
          @config.log_debug "get_palette_from_image: image.class=#{image.class} options=#{options.inspect}"
        end

        extract_from_image_source(image, options)
      end

      def extract_from_image_data(rgba_image, width : Int32, height : Int32, options : Options) : Array(RGB)
        src = rgba_image.pix
        extract_from_buffer(src, width, height, options)
      end

      def extract_from_buffer(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options) : Array(RGB)
        if width > @config.max_image_width || height > @config.max_image_height
          @config.log_debug "extract_from_buffer: dimensions #{width}x#{height} exceed max #{@config.max_image_width}x#{@config.max_image_height}"
          return [] of RGB
        end

        histo, total_pixels = build_buffer_histo(pixels, width, height, options)

        if total_pixels == 0
          return [] of RGB
        end

        quantize_palette(histo, options)[0...options.color_count]
      end

      private def quantize_palette(histo : Array(UInt32), options : Options) : Array(RGB)
        mmcq = Algorithm::MMCQ.new(histo, config: @config)
        vboxes = mmcq.quantize(options.color_count)

        palette = vboxes.compact_map do |box|
          next if box.count == 0
          box.average_color_rgb
        end

        sort_by_popularity(palette, histo)
      end

      private def build_buffer_histo(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options) : Tuple(Array(UInt32), Int32)
        histo = Array(UInt32).new(Constants::HISTOGRAM_SIZE, 0_u32)
        step = options.quality
        alpha_threshold = options.alpha_threshold

        total_pixels = Utils::HistogramProcessor.process_pixel_range(pixels, width, 0, height, step, alpha_threshold, histo)

        {histo, total_pixels}
      end

      private def sort_by_popularity(palette : Array(RGB), histo : Array(UInt32))
        palette.sort_by do |rgb|
          y, i, q = YIQConverter.quantize_from_rgb(rgb.r, rgb.g, rgb.b)
          idx = YIQConverter.to_index(y, i, q)
          count = histo[idx].to_i
          -count
        end
      end
    end
  end
end
