require "../types"

module PrismatIQ
  module Core
    class HistogramPool
      @pool : Array(Array(UInt32))
      @max_size : Int32
      @mutex : Mutex

      def initialize(@max_size : Int32 = 32)
        @pool = [] of Array(UInt32)
        @mutex = Mutex.new
      end

      def acquire : Array(UInt32)
        @mutex.synchronize do
          if @pool.empty?
            return Array(UInt32).new(Constants::HISTOGRAM_SIZE, 0_u32)
          else
            return @pool.pop
          end
        end
      end

      def release(histogram : Array(UInt32)) : Nil
        return if histogram.nil?

        @mutex.synchronize do
          if @pool.size < @max_size
            histogram.fill(0_u32)
            @pool.push(histogram)
          end
        end
      end

      def size : Int32
        @mutex.synchronize { @pool.size }
      end

      def clear : Nil
        @mutex.synchronize do
          @pool.clear
        end
      end

      def stats : NamedTuple(pool_size: Int32, max_size: Int32, total_capacity: Int32)
        @mutex.synchronize do
          {
            pool_size: @pool.size,
            max_size: @max_size,
            total_capacity: @pool.size * Constants::HISTOGRAM_SIZE
          }
        end
      end
    end

    class AdaptiveChunkSizer
      def self.calculate(image_size : Int32, thread_count : Int32) : Int32
        if image_size < 100_000
          return image_size
        elsif image_size < 1_000_000
          return (image_size // thread_count // 2).clamp(10_000, 100_000)
        else
          return (image_size // thread_count).clamp(50_000, 500_000)
        end
      end

      def self.should_use_parallel?(image_size : Int32) : Bool
        image_size > 100_000
      end

      def self.optimal_thread_count(image_size : Int32, max_threads : Int32) : Int32
        return 1 if image_size < 100_000
        return 2 if image_size < 500_000
        return 4 if image_size < 2_000_000
        return {max_threads, 8}.min
      end
    end
  end
end
