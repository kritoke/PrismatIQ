module PrismatIQ
  VERSION = "0.1.0"

  struct Color
    property y : Float64
    property i : Float64
    property q : Float64

    def initialize(@y : Float64, @i : Float64, @q : Float64)
    end

    def self.from_rgb(r : Int32, g : Int32, b : Int32)
      y = (0.299 * r) + (0.587 * g) + (0.114 * b)
      i = (0.596 * r) - (0.274 * g) - (0.322 * b)
      q = (0.211 * r) - (0.523 * g) + (0.312 * b)
      new(y, i, q)
    end

    def self.from_rgb(r : Float64, g : Float64, b : Float64)
      from_rgb(r.to_i, g.to_i, b.to_i)
    end

    def to_rgb : Tuple(Int32, Int32, Int32)
      r = ((@y + 0.956 * @i + 0.621 * @q).clamp(0, 255)).to_i
      g = ((@y - 0.272 * @i - 0.647 * @q).clamp(0, 255)).to_i
      b = ((@y - 1.106 * @i + 1.703 * @q).clamp(0, 255)).to_i
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

  struct RGB
    property r : Int32
    property g : Int32
    property b : Int32

    def initialize(@r : Int32, @g : Int32, @b : Int32)
    end

    def to_hex : String
      String.build do |str|
        str << '#'
        str << @r.to_s(16).rjust(2, '0')
        str << @g.to_s(16).rjust(2, '0')
        str << @b.to_s(16).rjust(2, '0')
      end
    end
  end

  struct VBox
    property y1 : Int32
    property y2 : Int32
    property i1 : Int32
    property i2 : Int32
    property q1 : Int32
    property q2 : Int32
    property count : Int32
    property histo : Hash(Int32, Int32)

    def initialize(@y1 : Int32, @y2 : Int32, @i1 : Int32, @i2 : Int32, @q1 : Int32, @q2 : Int32, @count : Int32 = 0, @histo : Hash(Int32, Int32) = Hash(Int32, Int32).new)
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

      y_sum = 0.0
      i_sum = 0.0
      q_sum = 0.0
      found = 0

      @histo.each do |index, freq|
        y, i, q = from_index(index)
        y_sum += y * freq
        i_sum += i * freq
        q_sum += q * freq
        found += freq
      end

      if found > 0
        Color.new(y_sum / found, i_sum / found, q_sum / found)
      else
        Color.new(0, 0, 0)
      end
    end

    def split : Tuple(VBox, V32)
      axis = find_split_axis
      return {self, VBox.new(0, 0, 0, 0, 0, 0)} if axis == -1

      indices = get_indices(axis)
      indices.sort!

      mid = indices.size // 2

      box1_y1, box1_y2, box1_i1, box1_i2, box1_q1, box1_q2 = @y1, @y2, @i1, @i2, @q1, @q2
      box2_y1, box2_y2, box2_i1, box2_i2, box2_q1, box2_q2 = @y1, @y2, @i1, @i2, @q1, @q2

      case axis
      when 0
        box1_y2 = indices[mid]
        box2_y1 = indices[mid] + 1
      when 1
        box1_i2 = indices[mid]
        box2_i1 = indices[mid] + 1
      when 2
        box1_q2 = indices[mid]
        box2_q1 = indices[mid] + 1
      end

      box1 = VBox.new(box1_y1, box1_y2, box1_i1, box1_i2, box1_q1, box1_q2, 0, @histo)
      box2 = VBox.new(box2_y1, box2_y2, box2_i1, box2_i2, box2_q1, box2_q2, 0, @histo)

      {box1, box2}
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
      else               2
      end
    end

    private def get_indices(axis : Int32) : Array(Int32)
      indices = Array(Int32).new
      @histo.each do |index, freq|
        y, i, q = from_index(index)
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
  end

  class PriorityQueue(T)
    @data : Array(T)

    def initialize(&@compare : T, T -> Int32)
      @data = Array(T).new
    end

    def initialize(compare : T, T -> Int32)
      initialize(&compare)
    end

    def push(item : T)
      @data.push(item)
      bubble_up(@data.size - 1)
    end

    def pop : T?
      return nil if @data.empty?

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

    private def bubble_up(index : Int32)
      while index > 0
        parent = (index - 1) // 2
        break if @compare.call(@data[index], @data[parent]) >= 0

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

        if left < len && @compare.call(@data[left], @data[smallest]) < 0
          smallest = left
        end

        if right < len && @compare.call(@data[right], @data[smallest]) < 0
          smallest = right
        end

        break if smallest == index

        @data[index], @data[smallest] = @data[smallest], @data[index]
        index = smallest
      end
    end
  end

  class MMCQ
    MAX_ITERATIONS = 1000
    SIGNIFICANCE = 0.001

    def initialize(@histo : Hash(Int32, Int32), @color_depth : Int32 = 5)
      @total = 0
      @histo.each { |_, v| @total += v }
    end

    def quantize(max_colors : Int32) : Array(VBox)
      if max_colors < 2 || @total == 0
        return [] of VBox
      end

      initial_box = build_initial_box
      boxes = [initial_box]

      pq = PriorityQueue(VBox).new { |a, b| b.priority <=> a.priority }
      pq.push(initial_box)

      iteration = 0
      while pq.size < max_colors && iteration < MAX_ITERATIONS
        iteration += 1

        box = pq.pop
        break unless box

        vbox1, vbox2 = box.split
        break if vbox1 == box

        pq.push(vbox1)
        pq.push(vbox2)
      end

      boxes = Array(VBox).new
      while !pq.empty?
        box = pq.pop
        boxes << box if box && box.count > 0
      end

      boxes
    end

    private def build_initial_box : VBox
      y1 = 0
      y2 = 31
      i1 = 0
      i2 = 31
      q1 = 0
      q2 = 31

      @histo.each_key do |index|
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

  def self.get_palette(path : String, color_count : Int32 = 5, quality : Int32 = 10) : Array(RGB)
    img = CrImage.read(path)
    get_palette(img, color_count, quality)
  end

  def self.get_palette(io : IO, color_count : Int32 = 5, quality : Int32 = 10) : Array(RGB)
    img = CrImage.read(io)
    get_palette(img, color_count, quality)
  end

  def self.get_palette(img : CrImage, color_count : Int32 = 5, quality : Int32 = 10) : Array(RGB)
    pixels = img.pix
    width = img.width
    height = img.height
    histo = Hash(Int32, Int32).new(0)
    total_pixels = 0

    step = quality < 1 ? 1 : quality

    y_coord = 0
    while y_coord < height
      x_coord = 0
      while x_coord < width
        idx = (y_coord * width + x_coord) * 4

        r = pixels[idx]
        g = pixels[idx + 1]
        b = pixels[idx + 2]
        a = pixels[idx + 3]

        if a >= 125
          y = ((0.299 * r) + (0.587 * g) + (0.114 * b)).to_i
          i = ((0.596 * r) - (0.274 * g) - (0.322 * b)).to_i
          q = ((0.211 * r) - (0.523 * g) + (0.312 * b)).to_i

          y = y.clamp(0, 31)
          i = i.clamp(0, 31)
          q = q.clamp(0, 31)

          index = VBox.to_index(y, i, q)
          histo[index] = histo.fetch(index, 0) + 1
          total_pixels += 1
        end

        x_coord += step
      end
      y_coord += step
    end

    if total_pixels == 0
      return [RGB.new(0, 0, 0)]
    end

    mmcq = MMCQ.new(histo)
    vboxes = mmcq.quantize(color_count)

    palette = Array(RGB).new
    vboxes.each do |box|
      if box.count > 0
        avg_color = box.average_color
        rgb = avg_color.to_rgb_obj
        palette << rgb
      end
    end

    palette = sort_by_popularity(palette, histo)

    palette[0...color_count]
  end

  def self.get_color(path : String) : RGB
    get_palette(path, color_count: 1, quality: 1)[0]
  end

  def self.get_color(io : IO) : RGB
    get_palette(io, color_count: 1, quality: 1)[0]
  end

  def self.get_color(img : CrImage) : RGB
    get_palette(img, color_count: 1, quality: 1)[0]
  end

  private def self.sort_by_popularity(palette : Array(RGB), histo : Hash(Int32, Int32)) : Array(RGB)
    palette.sort_by do |rgb|
      y = ((0.299 * rgb.r) + (0.587 * rgb.g) + (0.114 * rgb.b)).to_i
      i = ((0.596 * rgb.r) - (0.274 * rgb.g) - (0.322 * rgb.b)).to_i
      q = ((0.211 * rgb.r) - (0.523 * rgb.g) + (0.312 * rgb.b)).to_i

      y = y.clamp(0, 31)
      i = i.clamp(0, 31)
      q = q.clamp(0, 31)

      -histo.fetch(VBox.to_index(y, i, q), 0)
    end
  end
end
