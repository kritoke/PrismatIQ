module PrismatIQ
  module Algorithm
    class PriorityQueue(T)
      @data : Array(T)
      @compare : Proc(T, T, Int32?)

      def initialize(&compare : Proc(T, T, Int32?))
        @data = Array(T).new
        @compare = compare
      end

      def push(item : T)
        @data.push(item)
        bubble_up(@data.size - 1)
      end

      def pop : T?
        return if @data.empty?

        top = @data[0]
        last = @data.pop

        if !@data.empty?
          @data[0] = last
          sink_down(0)
        end

        top
      end

      def peek : T?
        @data[0]?
      end

      def size : Int32
        @data.size
      end

      def empty? : Bool
        @data.empty?
      end

      private def cmp(a : T, b : T) : Int32
        res = @compare.call(a, b)
        if res.nil?
          0
        else
          res
        end
      end

      private def bubble_up(index : Int32)
        while index > 0
          parent = (index - 1) // 2
          break if cmp(@data[index], @data[parent]) >= 0

          @data[index], @data[parent] = @data[parent], @data[index]
          index = parent
        end
      end

      private def sink_down(index : Int32)
        len = @data.size
        loop do
          left = 2 * index + 1
          right = 2 * index + 2
          smallest = index

          if left < len && cmp(@data[left], @data[smallest]) < 0
            smallest = left
          end

          if right < len && cmp(@data[right], @data[smallest]) < 0
            smallest = right
          end

          break if smallest == index

          @data[index], @data[smallest] = @data[smallest], @data[index]
          index = smallest
        end
      end
    end
  end
end
