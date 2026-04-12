require "../types"

module PrismatIQ
  module Core
    # Optimized histogram allocation for parallel processing.
    #
    # Instead of using a shared pool with mutex contention, this implementation
    # provides lazy allocation for each worker fiber with direct access.
    #
    # ### Thread Safety
    # - Each histogram is used by only one fiber at a time
    # - No mutex required for allocation/deallocation
    # - Safe for concurrent use across multiple extraction operations
    #
    # ### Memory Management
    # - Histograms are allocated on-demand per worker (lazy allocation)
    # - Only the histograms actually used are allocated
    # - Memory usage is predictable and bounded by worker count
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

        histo = (@histograms[index] ||= Array(UInt32).new(Constants::HISTOGRAM_SIZE, 0_u32))
        histo.fill(0_u32)
        @used[index] = true
        histo
      end

      def size : Int32
        @used.count(&.== true)
      end

      def clear : Nil
        @used.fill(false)
        @histograms.each &.try &.fill(0_u32)
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
        if image_size < Constants::ParallelProcessing::SMALL_IMAGE_THRESHOLD
          image_size
        elsif image_size < Constants::ParallelProcessing::MEDIUM_IMAGE_THRESHOLD
          (image_size // thread_count // 2).clamp(
            Constants::ParallelProcessing::MIN_CHUNK_SIZE_SMALL,
            Constants::ParallelProcessing::MAX_CHUNK_SIZE_SMALL)
        else
          (image_size // thread_count).clamp(
            Constants::ParallelProcessing::MIN_CHUNK_SIZE_LARGE,
            Constants::ParallelProcessing::MAX_CHUNK_SIZE_LARGE)
        end
      end

      def self.should_use_parallel?(image_size : Int32) : Bool
        image_size > Constants::ParallelProcessing::SMALL_IMAGE_THRESHOLD
      end

      def self.optimal_thread_count(image_size : Int32, max_threads : Int32) : Int32
        if image_size < Constants::ParallelProcessing::SMALL_IMAGE_THRESHOLD
          1
        elsif image_size < Constants::ParallelProcessing::THREAD_COUNT_MEDIUM_THRESHOLD
          2
        elsif image_size < Constants::ParallelProcessing::LARGE_IMAGE_THRESHOLD
          Constants::ParallelProcessing::GOOD_PARALLELISM
        else
          {max_threads, Constants::ParallelProcessing::MAX_THREAD_COUNT}.min
        end
      end
    end
  end
end
