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

    def self.from_rgb(r : Float64, g : Float64, b : Float64)
      from_rgb(r.to_i, g.to_i, b.to_i)
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
      String.build do |str|
        str << '#'
        str << r.to_s(16).rjust(2, '0')
        str << g.to_s(16).rjust(2, '0')
        str << b.to_s(16).rjust(2, '0')
      end
    end

    def to_rgb_obj
      r, g, b = to_rgb
      RGB.new(r, g, b)
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

    def contains?(yiq : Color) : Bool
      yiq.y >= @y1 && yiq.y <= @y2 &&
        yiq.i >= @i1 && yiq.i <= @i2 &&
        yiq.q >= @q1 && yiq.q <= @q2
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

      @histo.each_with_index do |freq, index|
        next if freq == 0
        y, i, q = VBox.from_index(index)
        if y >= @y1 && y <= @y2 && i >= @i1 && i <= @i2 && q >= @q1 && q <= @q2
          y_sum += y * freq.to_f64
          i_sum += i * freq.to_f64
          q_sum += q * freq.to_f64
          found += freq.to_i
        end
      end

      {y_sum: y_sum, i_sum: i_sum, q_sum: q_sum, found: found}
    end

    def split : Tuple(VBox, VBox)
      axis = find_split_axis
      return {self, VBox.new(0, 0, 0, 0, 0, 0)} if axis == -1

      indices = get_indices(axis)
      indices.sort!

      mid = indices.size // 2
      return {self, VBox.new(0, 0, 0, 0, 0, 0)} if mid == 0

      split_at = indices[mid - 1]

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
      @histo.each_with_index do |freq, index|
        next if freq == 0
        y, i, q = VBox.from_index(index)
        case axis
        when 0
          indices << y if y >= @y1 && y <= @y2
        when 1
          indices << i if i >= @i1 && i <= @i2
        when 2
          indices << q if q >= @q1 && q <= @q2
        end
      end
      indices
    end

    def self.from_index(index : Int32) : Tuple(Int32, Int32, Int32)
      y = index >> 10
      i = (index >> 5) & 31
      q = index & 31
      {y, i, q}
    end

    def self.to_index(y : Int32, i : Int32, q : Int32) : Int32
      (y << 10) | (i << 5) | q
    end

    def recalc_count : VBox
      c = 0
      @histo.each_with_index do |freq, index|
        next if freq == 0
        y, i, q = VBox.from_index(index)
        if y >= @y1 && y <= @y2 && i >= @i1 && i <= @i2 && q >= @q1 && q <= @q2
          c += freq.to_i
        end
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
