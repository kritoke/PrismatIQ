require "../types"
require "../options"
require "../config"
require "../algorithm/mmcq"
require "../algorithm/color_space"
require "../core/histogram_pool"

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
    # - **Thread-Local Processing**: Histogram building uses thread-local storage
    # - **Safe Concurrent Access**: Multiple threads can use different instances
    #   simultaneously without coordination
    # - **Config Isolation**: Each instance uses its own Config for processing
    #
    # ## Memory Optimization
    #
    # - Uses `HistogramPool` for object reuse (25-40% memory reduction)
    # - Implements adaptive chunk sizing based on image dimensions
    # - Processes histograms in CPU cache-friendly chunks
    #
    # ## Usage
    #
    # ```
    # extractor = PrismatIQ::Core::PaletteExtractor.new
    # palette = extractor.extract_from_path("image.jpg", options)
    # ```
    class PaletteExtractor
      def initialize(@config : Config = Config.default)
      end

      def extract_from_path(path : String, options : Options) : Array(RGB)
        options.validate!
        @config.debug_log "get_palette(path): path=#{path} options=#{options.inspect}"
        img = CrImage.read(path)
        extract_from_image(img.as(CrImage::Image), options)
      end

      def extract_from_io(io : IO, options : Options) : Array(RGB)
        options.validate!
        img = CrImage.read(io)
        extract_from_image(img.as(CrImage::Image), options)
      end

      def extract_from_image(image, options : Options) : Array(RGB)
        options.validate!
        @config.debug_log "get_palette_from_image: image.class=#{image.class} options=#{options.inspect}"
        rgba_image = CrImage::Pipeline.new(image).result
        width = rgba_image.bounds.width.to_i32
        height = rgba_image.bounds.height.to_i32

        src = rgba_image.pix
        extract_from_buffer(src, width, height, options)
      end

      def extract_from_buffer(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options) : Array(RGB)
        options.validate!
        histo, total_pixels = build_histo_from_buffer(pixels, width, height, options)

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

      private def build_histo_from_buffer(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options) : Tuple(Array(UInt32), Int32)
        histo = Array(UInt32).new(Constants::HISTOGRAM_SIZE, 0_u32)
        step = options.quality < 1 ? 1 : options.quality
        alpha_threshold = options.alpha_threshold

        image_size = width * height
        use_parallel = AdaptiveChunkSizer.should_use_parallel?(image_size) && options.threads != 1

        if !use_parallel || options.threads <= 1
          total_pixels = process_pixel_range(pixels, width, 0, height, step, alpha_threshold, histo)
        else
          thread_count = AdaptiveChunkSizer.optimal_thread_count(image_size, @config.thread_count_for(height, options.threads))

          channel = Channel(Tuple(Array(UInt32)?, Int32)).new(thread_count)

          rows_per = (height + thread_count - 1) // thread_count

          pool = HistogramPool.new(thread_count)
          
          # Track actual number of spawned fibers to avoid deadlock
          spawned_count = 0

          thread_count.times do |thread_idx|
            start_row = thread_idx * rows_per
            break if start_row >= height
            end_row = {start_row + rows_per, height}.min
            
            spawned_count += 1

            spawn do
              begin
                local_histo = pool.acquire(thread_idx)
                local_count = process_pixel_range(pixels, width, start_row, end_row, step, alpha_threshold, local_histo)
                channel.send({local_histo, local_count})
              rescue ex : Exception
                @config.debug_log "Worker fiber failed: #{ex.class.name}: #{ex.message}"
                channel.send({nil, 0})
              end
            end
          end

          total_pixels = 0
          spawned_count.times do
            local_histo, local_count = channel.receive
            if local_histo
              merge_histograms(histo, local_histo)
              total_pixels += local_count
            end
          end
        end

        {histo, total_pixels}
      end

      private def merge_histograms(dest : Array(UInt32), src : Array(UInt32)) : Nil
        dest.size.times do |i|
          dest[i] += src[i]
        end
      end

      @[AlwaysInline]
      private def process_pixel_range(pixels : Slice(UInt8), width : Int32, start_row : Int32, end_row : Int32, step : Int32, alpha_threshold : UInt8, histo : Array(UInt32)) : Int32
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
