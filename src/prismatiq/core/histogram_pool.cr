require "../types"

module PrismatIQ
  module Core
    # Optimized histogram allocation for parallel processing.
    #
    # Instead of using a shared pool with mutex contention, this implementation
    # pre-allocates histograms for each worker fiber and provides direct access.
    #
    # ### Thread Safety
    # - Each histogram is used by only one fiber at a time
    # - No mutex required for allocation/deallocation
    # - Safe for concurrent use across multiple extraction operations
    #
    # ### Memory Management
    # - Histograms are pre-allocated based on expected worker count
    # - No dynamic allocation during processing
    # - Memory usage is predictable and bounded
    class HistogramPool
      @histograms : Array(Array(UInt32)?)
      @used : Array(Bool)

      def initialize(worker_count : Int32)
        @histograms = Array(Array(UInt32)?).new(worker_count) { nil }
        @used = Array(Bool).new(worker_count, false)
      end

      def acquire(index : Int32) : Array(UInt32)
        if index >= @histograms.size
          raise ArgumentError.new("Index #{index} out of bounds for pool size #{@histograms.size}")
        end

        if @histograms[index].nil?
          @histograms[index] = Array(UInt32).new(Constants::HISTOGRAM_SIZE, 0_u32)
        else
          @histograms[index].as(Array(UInt32)).fill(0_u32)
        end
        @used[index] = true
        @histograms[index].as(Array(UInt32))
      end

      def release(index : Int32) : Nil
        if index < @used.size
          @used[index] = false
        end
      end

      def size : Int32
        @used.count(&.== true)
      end

      def clear : Nil
        @used.fill(false)
        @histograms.each do |histo|
          if histo
            histo.fill(0_u32)
          end
        end
      end

      def stats : NamedTuple(pool_size: Int32, total_capacity: Int32)
        {
          pool_size:      @used.count(&.== true),
          total_capacity: @histograms.size * Constants::HISTOGRAM_SIZE,
        }
      end
    end

    class AdaptiveChunkSizer
      def self.calculate(image_size : Int32, thread_count : Int32) : Int32
        if image_size < 100_000
          image_size
        elsif image_size < 1_000_000
          (image_size // thread_count // 2).clamp(10_000, 100_000)
        else
          (image_size // thread_count).clamp(50_000, 500_000)
        end
      end

      def self.should_use_parallel?(image_size : Int32) : Bool
        image_size > 100_000
      end

      def self.optimal_thread_count(image_size : Int32, max_threads : Int32) : Int32
        if image_size < 100_000
          1
        elsif image_size < 500_000
          2
        elsif image_size < 2_000_000
          4
        else
          {max_threads, 8}.min
        end
      end
    end
  end
end
