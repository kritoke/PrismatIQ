require "./rgb"
require "./options"
require "./result"
require "./algorithm/color_space"

module PrismatIQ
  struct Color
    getter y : Float64
    getter i : Float64
    getter q : Float64

    def initialize(@y : Float64, @i : Float64, @q : Float64)
    end

    def self.from_rgb(r : Int32, g : Int32, b : Int32)
      YIQConverter.from_rgb(r, g, b)
    end

    def to_rgb : Tuple(Int32, Int32, Int32)
      r = ((@y + Constants::YIQ::R_FROM_I * @i + Constants::YIQ::R_FROM_Q * @q).clamp(0, 255)).to_i
      g = ((@y + Constants::YIQ::G_FROM_I * @i + Constants::YIQ::G_FROM_Q * @q).clamp(0, 255)).to_i
      b = ((@y + Constants::YIQ::B_FROM_I * @i + Constants::YIQ::B_FROM_Q * @q).clamp(0, 255)).to_i
      {r, g, b}
    end

    def to_rgb_from_quantized : Tuple(Int32, Int32, Int32)
      y_full = @y / 31.0 * 255.0
      i_full = @i / 31.0 * 304.0 - 152.0
      q_full = @q / 31.0 * 268.0 - 134.0

      r = ((y_full + Constants::YIQ::R_FROM_I * i_full + Constants::YIQ::R_FROM_Q * q_full).clamp(0, 255)).to_i
      g = ((y_full + Constants::YIQ::G_FROM_I * i_full + Constants::YIQ::G_FROM_Q * q_full).clamp(0, 255)).to_i
      b = ((y_full + Constants::YIQ::B_FROM_I * i_full + Constants::YIQ::B_FROM_Q * q_full).clamp(0, 255)).to_i
      {r, g, b}
    end

    def to_hex : String
      r, g, b = to_rgb
      "#%02x%02x%02x" % [r, g, b]
    end
  end

  struct VBox
    getter y1 : Int32
    getter y2 : Int32
    getter i1 : Int32
    getter i2 : Int32
    getter q1 : Int32
    getter q2 : Int32
    getter count : Int32
    getter histo : Array(UInt32)

    def initialize(@y1 : Int32, @y2 : Int32, @i1 : Int32, @i2 : Int32, @q1 : Int32, @q2 : Int32, @count : Int32 = 0, @histo : Array(UInt32) = Array(UInt32).new(Constants::HISTOGRAM_SIZE, 0_u32))
    end

    def volume
      ((@y2 - @y1 + 1) * (@i2 - @i1 + 1) * (@q2 - @q1 + 1)).to_f64
    end

    def priority
      @count.to_f64 * volume
    end

    def average_color : Color
      if @count == 0
        return Color.new(0, 0, 0)
      end

      sums = compute_weighted_sums
      if sums[:found] > 0
        Color.new(sums[:y_sum] / sums[:found], sums[:i_sum] / sums[:found], sums[:q_sum] / sums[:found])
      else
        Color.new(0, 0, 0)
      end
    end

    def average_color_rgb : RGB
      if @count == 0
        return RGB.new(0, 0, 0)
      end

      sums = compute_weighted_sums
      if sums[:found] > 0
        color = Color.new(sums[:y_sum] / sums[:found], sums[:i_sum] / sums[:found], sums[:q_sum] / sums[:found])
        r, g, b = color.to_rgb_from_quantized
        RGB.new(r, g, b)
      else
        RGB.new(0, 0, 0)
      end
    end

    private def compute_weighted_sums : NamedTuple(y_sum: Float64, i_sum: Float64, q_sum: Float64, found: Int32)
      y_sum = 0.0
      i_sum = 0.0
      q_sum = 0.0
      found = 0

      y = @y1
      while y <= @y2
        y_offset = y << 10
        i = @i1
        while i <= @i2
          i_offset = i << 5
          q = @q1
          while q <= @q2
            freq = @histo[y_offset | i_offset | q]
            if freq > 0
              f = freq.to_f64
              y_sum += y.to_f64 * f
              i_sum += i.to_f64 * f
              q_sum += q.to_f64 * f
              found += freq.to_i
            end
            q += 1
          end
          i += 1
        end
        y += 1
      end

      {y_sum: y_sum, i_sum: i_sum, q_sum: q_sum, found: found}
    end

    def split(rng : Random::PCG32 = Random::PCG32.new) : Tuple(VBox, VBox)
      axis = find_split_axis
      return {self, VBox.new(0, 0, 0, 0, 0, 0)} if axis == -1

      indices = get_indices(axis)

      return {self, VBox.new(0, 0, 0, 0, 0, 0)} if indices.empty?

      mid = indices.size // 2
      split_at = VBox.quickselect(indices, mid - 1, rng)

      box1_y1, box1_y2, box1_i1, box1_i2, box1_q1, box1_q2 = @y1, @y2, @i1, @i2, @q1, @q2
      box2_y1, box2_y2, box2_i1, box2_i2, box2_q1, box2_q2 = @y1, @y2, @i1, @i2, @q1, @q2

      case axis
      when 0
        box1_y2 = split_at
        box2_y1 = split_at + 1
      when 1
        box1_i2 = split_at
        box2_i1 = split_at + 1
      when 2
        box1_q2 = split_at
        box2_q1 = split_at + 1
      end

      box1 = VBox.new(box1_y1, box1_y2, box1_i1, box1_i2, box1_q1, box1_q2, 0, @histo)
      box2 = VBox.new(box2_y1, box2_y2, box2_i1, box2_i2, box2_q1, box2_q2, 0, @histo)

      {box1.recalc_count, box2.recalc_count}
    end

    # Quickselect algorithm to find k-th smallest element in O(n) average time.
    # Uses in-place Lomuto partitioning to avoid allocations.
    # WARNING: Mutates the input array in-place.
    def self.quickselect(arr : Array(Int32), k : Int32, rng : Random::PCG32 = Random::PCG32.new) : Int32
      if arr.size <= 32
        sorted = arr.sort
        return sorted[k]
      end

      lo = 0
      hi = arr.size - 1

      while lo < hi
        pivot_idx = lo + rng.rand(hi - lo + 1)
        pivot = arr[pivot_idx]
        arr[pivot_idx] = arr[hi]
        arr[hi] = pivot

        store = lo
        i = lo
        while i < hi
          if arr[i] < pivot
            arr[store], arr[i] = arr[i], arr[store]
            store += 1
          end
          i += 1
        end

        arr[store], arr[hi] = arr[hi], arr[store]

        if k < store
          hi = store - 1
        elsif k > store
          lo = store + 1
        else
          return arr[store]
        end
      end

      arr[lo]
    end

    private def find_split_axis : Int32
      y_range = @y2 - @y1
      i_range = @i2 - @i1
      q_range = @q2 - @q1

      max_range = {y_range, i_range, q_range}.max
      return -1 if max_range == 0

      case max_range
      when y_range then 0
      when i_range then 1
      else              2
      end
    end

    private def get_indices(axis : Int32) : Array(Int32)
      indices = Array(Int32).new
      y = @y1
      while y <= @y2
        y_offset = y << 10
        i = @i1
        while i <= @i2
          i_offset = i << 5
          q = @q1
          while q <= @q2
            freq = @histo[y_offset | i_offset | q]
            if freq > 0
              case axis
              when 0 then indices << y
              when 1 then indices << i
              when 2 then indices << q
              end
            end
            q += 1
          end
          i += 1
        end
        y += 1
      end
      indices
    end

    def recalc_count : VBox
      c = 0
      y = @y1
      while y <= @y2
        y_offset = y << 10
        i = @i1
        while i <= @i2
          i_offset = i << 5
          q = @q1
          while q <= @q2
            c += @histo[y_offset | i_offset | q].to_i
            q += 1
          end
          i += 1
        end
        y += 1
      end
      VBox.new(@y1, @y2, @i1, @i2, @q1, @q2, c, @histo)
    end
  end

  struct PaletteEntry
    include JSON::Serializable
    include YAML::Serializable

    property rgb : RGB
    property count : Int32
    property percent : Float64

    def initialize(@rgb : RGB, @count : Int32, @percent : Float64)
    end
  end

  class ValidationError < Exception
  end
end
