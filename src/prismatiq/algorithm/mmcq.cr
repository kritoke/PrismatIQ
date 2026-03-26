require "./priority_queue"
require "../types"
require "../config"

module PrismatIQ
  module Algorithm
    class MMCQ
      MAX_ITERATIONS =  1000
      SIGNIFICANCE   = 0.001

      def initialize(@histo : Array(UInt32), @color_depth : Int32 = 5, config : Config = Config.default)
        @total = 0
        @histo.each do |v|
          @total += v.to_i
        end
        @config = config
      end

      def quantize(max_colors : Int32) : Array(VBox)
        return [] of VBox if max_colors < 1 || @total == 0
        return [build_initial_box] if max_colors == 1

        initial_box = build_initial_box
        if @config.debug_log?
          log_debug_initial(initial_box)
        end

        pq = Algorithm::PriorityQueue(VBox).new(&box_comparator)
        pq.push(initial_box)

        iteration = 0
        while pq.size < max_colors && iteration < MAX_ITERATIONS
          iteration += 1
          if @config.debug_log?
            log_debug_iteration(iteration, pq.size)
          end

          box = pq.pop
          break unless box
          if @config.debug_log?
            log_popped_box(box)
          end

          vbox1, vbox2 = box.split

          if vbox1 == box
            pq.push(box)
            break
          end

          if @config.debug_log?
            log_split_result(vbox1, vbox2)
          end

          pq.push(vbox1) if vbox1.count > 0
          pq.push(vbox2) if vbox2.count > 0
        end

        collect_final_boxes(pq)
      end

      private def box_comparator
        ->(a : VBox, b : VBox) {
          cmp = b.priority <=> a.priority
          return cmp if cmp != 0
          cmp2 = b.count <=> a.count
          return cmp2 if cmp2 != 0
          cmp3 = a.y1 <=> b.y1
          return cmp3 if cmp3 != 0
          cmp3 = a.i1 <=> b.i1
          return cmp3 if cmp3 != 0
          a.q1 <=> b.q1
        }
      end

      private def log_debug_initial(initial_box : VBox)
        @config.debug_log "MMCQ: total=#{@total} initial_box.count=#{initial_box.count}"
      end

      private def log_debug_iteration(iteration : Int32, pq_size : Int32)
        @config.debug_log "MMCQ iter=#{iteration} pq_size=#{pq_size}"
      end

      private def log_popped_box(box : VBox?)
        msg = box ? "MMCQ popped box count=#{box.count}" : "MMCQ popped nil box"
        @config.debug_log msg
      end

      private def log_split_result(vbox1 : VBox, vbox2 : VBox)
        @config.debug_log "MMCQ split -> vbox1.count=#{vbox1.count} vbox2.count=#{vbox2.count}"
      end

      private def collect_final_boxes(pq : Algorithm::PriorityQueue(VBox)) : Array(VBox)
        boxes = Array(VBox).new
        while !pq.empty?
          box = pq.pop
          boxes << box if box && box.count > 0
        end
        boxes
      end

      private def build_initial_box : VBox
        y1, y2, i1, i2, q1, q2 = 31, 0, 31, 0, 31, 0

        @histo.each_with_index do |freq, index|
          next if freq == 0
          y, i, q = VBox.from_index(index)
          y1 = y if y < y1
          y2 = y if y > y2
          i1 = i if i < i1
          i2 = i if i > i2
          q1 = q if q < q1
          q2 = q if q > q2
        end

        VBox.new(y1, y2, i1, i2, q1, q2, @total, @histo)
      end
    end
  end
end
