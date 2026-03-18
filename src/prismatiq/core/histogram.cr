require "../types"
require "../algorithm/color_space"
require "../utils/histogram_processor"

module PrismatIQ
  module Core
    class HistogramBuilder
      include Utils::HistogramProcessor

      def self.build(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options, config : Config = Config.default) : Tuple(Array(UInt32), Int32)
        histo = Array(UInt32).new(Constants::HISTOGRAM_SIZE, 0_u32)
        step = options.quality < 1 ? 1 : options.quality
        alpha_threshold = options.alpha_threshold

        if options.threads <= 1
          total_pixels = Utils::HistogramProcessor.process_pixel_range(pixels, width, 0, height, step, alpha_threshold, histo)
        else
          total_pixels = build_parallel(pixels, width, height, step, alpha_threshold, histo, options, config)
        end

        {histo, total_pixels}
      end

      private def self.build_parallel(pixels : Slice(UInt8), width : Int32, height : Int32, step : Int32, alpha_threshold : UInt8, histo : Array(UInt32), options : Options, config : Config) : Int32
        thread_count = config.thread_count_for(height, options.threads)
        locals = Array(Array(UInt32)?).new(thread_count, nil)
        totals = Array(Int32).new(thread_count, 0)
        workers = Array(Thread).new

        rows_per = (height + thread_count - 1) // thread_count

        thread_count.times do |thread_idx|
          start_row = thread_idx * rows_per
          break if start_row >= height
          end_row = {start_row + rows_per, height}.min

          local_idx = thread_idx

          workers << Thread.new do
            local_histo = Array(UInt32).new(Constants::HISTOGRAM_SIZE, 0_u32)
            local_count = Utils::HistogramProcessor.process_pixel_range(pixels, width, start_row, end_row, step, alpha_threshold, local_histo)
            locals[local_idx] = local_histo
            totals[local_idx] = local_count
          end
        end

        workers.each(&.join)
        merge_chunked(histo, locals, config)
      end

      private def self.merge_chunked(histo : Array(UInt32), locals : Array(Array(UInt32)?), config : Config) : Int32
        total = 0

        chunk = config.merge_chunk.nil? ? nil : config.merge_chunk
        if chunk.nil?
          cache_bytes = ::PrismatIQ::CPU.l2_cache_bytes || 256 * 1024
          chunk = [(cache_bytes // 4 // locals.size), 1024].max
        end

        start = 0
        while start < Constants::HISTOGRAM_SIZE
          chunk_end = {start + chunk, Constants::HISTOGRAM_SIZE}.min
          idx = start
          while idx < chunk_end
            sum = 0_u32
            j = 0
            while j < locals.size
              local = locals[j]
              if local
                sum += local[idx]
              end
              j += 1
            end
            histo[idx] = sum
            total += sum.to_i
            idx += 1
          end
          start += chunk
        end
        total
      end
    end
  end
end
