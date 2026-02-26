require "./cpu_cores"
require "./prismatiq/color_extractor"
require "crimage"
require "./prismatiq/tempfile_helper"
require "./prismatiq/ico"

module PrismatIQ
  VERSION = "0.2.0"

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

  # Quantize Y/I/Q channels into 5-bit (0..31) bins from RGB components.
  # Y is in range ~0..255 so divide by 8.0. I/Q can be negative so shift by +128
  # to map to unsigned range before dividing. Clamp to [0,31] to be safe.
  private def self.quantize_yiq_from_rgb(r : Int32, g : Int32, b : Int32) : Tuple(Int32, Int32, Int32)
    y = (0.299 * r) + (0.587 * g) + (0.114 * b)
    i = (0.596 * r) - (0.274 * g) - (0.322 * b)
    q = (0.211 * r) - (0.523 * g) + (0.312 * b)

    # Preserve original behavior: convert to integer and clamp to 0..31.
    # This matches prior implementation used by tests, while ensuring no OOB.
    y_q = (y.to_i).clamp(0, 31)
    i_q = (i.to_i).clamp(0, 31)
    q_q = (q.to_i).clamp(0, 31)
    {y_q, i_q, q_q}
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

  # Validation exception for invalid input parameters
  class ValidationError < Exception
  end

  # Validate input parameters for palette extraction methods
  private def self.validate_params(color_count : Int32, quality : Int32) : Nil
    if color_count < 1
      raise ValidationError.new("color_count must be >= 1, got #{color_count}")
    end
    if quality < 1
      raise ValidationError.new("quality must be >= 1, got #{quality}")
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
    # fixed-size histogram (32*32*32 = 32768 entries)
    property histo : Array(UInt32)

    def initialize(@y1 : Int32, @y2 : Int32, @i1 : Int32, @i2 : Int32, @q1 : Int32, @q2 : Int32, @count : Int32 = 0, @histo : Array(UInt32) = Array(UInt32).new(32768, 0_u32))
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

      @histo.each_with_index do |freq, index|
        next if freq == 0
        y, i, q = VBox.from_index(index)
        # Only include colors inside this vbox
        if y >= @y1 && y <= @y2 && i >= @i1 && i <= @i2 && q >= @q1 && q <= @q2
          y_sum += y * freq.to_f64
          i_sum += i * freq.to_f64
          q_sum += q * freq.to_f64
          found += freq.to_i
        end
      end

      if found > 0
        Color.new(y_sum / found, i_sum / found, q_sum / found)
      else
        Color.new(0, 0, 0)
      end
    end

    def split : Tuple(VBox, VBox)
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

      # Recalculate counts for the new boxes so MMCQ can use them
      box1.recalc_count
      box2.recalc_count

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

    def recalc_count : Int32
      c = 0
      @histo.each_with_index do |freq, index|
        next if freq == 0
        y, i, q = VBox.from_index(index)
        if y >= @y1 && y <= @y2 && i >= @i1 && i <= @i2 && q >= @q1 && q <= @q2
          c += freq.to_i
        end
      end
      @count = c
      @count
    end
  end

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

    private def cmp(a : T, b : T) : Int32
      # Normalize nil to 0
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

  class MMCQ
    MAX_ITERATIONS =  1000
    SIGNIFICANCE   = 0.001

    def initialize(@histo : Array(UInt32), @color_depth : Int32 = 5)
      @total = 0
      @histo.each do |v|
        @total += v.to_i
      end
    end

    def quantize(max_colors : Int32) : Array(VBox)
      if max_colors < 2 || @total == 0
        return [] of VBox
      end

      initial_box = build_initial_box
      if ENV.has_key?("PRISMATIQ_DEBUG") && ENV["PRISMATIQ_DEBUG"]
        puts "MMCQ: total=#{@total} initial_box.count=#{initial_box.count}"
      end
      boxes = [initial_box]

      pq = PriorityQueue(VBox).new do |a, b|
        # Primary sort by priority (higher first). Tie-break deterministically by count
        # and then by the box coordinates to ensure stable behavior across runs.
        cmp = b.priority <=> a.priority
        if cmp == 0
          cmp2 = b.count <=> a.count
          if cmp2 == 0
            cmp3 = a.y1 <=> b.y1
            cmp3 = a.i1 <=> b.i1 if cmp3 == 0
            cmp3 = a.q1 <=> b.q1 if cmp3 == 0
            cmp3
          else
            cmp2
          end
        else
          cmp
        end
      end
      pq.push(initial_box)

      iteration = 0
      while pq.size < max_colors && iteration < MAX_ITERATIONS
        iteration += 1
        if ENV.has_key?("PRISMATIQ_DEBUG") && ENV["PRISMATIQ_DEBUG"]
          puts "MMCQ iter=#{iteration} pq_size=#{pq.size}"
        end

        box = pq.pop
        if ENV.has_key?("PRISMATIQ_DEBUG") && ENV["PRISMATIQ_DEBUG"]
          if box
            puts "MMCQ popped box count=#{box.count}"
          else
            puts "MMCQ popped nil box"
          end
        end
        break unless box

        vbox1, vbox2 = box.split

        if vbox1 == box
          # can't split further, push original back and stop
          pq.push(box)
          break
        end

        if ENV.has_key?("PRISMATIQ_DEBUG") && ENV["PRISMATIQ_DEBUG"]
          puts "MMCQ split -> vbox1.count=#{vbox1.count} vbox2.count=#{vbox2.count}"
        end

        # Only push non-empty boxes
        pq.push(vbox1) if vbox1.count > 0
        pq.push(vbox2) if vbox2.count > 0
      end

      boxes = Array(VBox).new
      while !pq.empty?
        box = pq.pop
        boxes << box if box && box.count > 0
      end

      boxes
    end

    private def build_initial_box : VBox
      # initialize mins to max possible and maxs to min possible so min/max logic works
      y1 = 31
      y2 = 0
      i1 = 31
      i2 = 0
      q1 = 31
      q2 = 0

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

  def self.get_palette(path : String, color_count : Int32 = 5, quality : Int32 = 10) : Array(RGB)
    validate_params(color_count, quality)
    if ENV.has_key?("PRISMATIQ_DEBUG") && ENV["PRISMATIQ_DEBUG"]
      STDERR.puts "get_palette(path): path=#{path} color_count=#{color_count} quality=#{quality}"
    end
    img = CrImage.read(path)
    # Cast to CrImage::Image to satisfy compile-time dispatch and call the
    # concrete helper which operates on CrImage::Image specifically.
    get_palette_from_image(img.as(CrImage::Image), color_count, quality)
  end

  def self.get_palette(io : IO, color_count : Int32 = 5, quality : Int32 = 10) : Array(RGB)
    validate_params(color_count, quality)
    img = CrImage.read(io)
    get_palette_from_image(img.as(CrImage::Image), color_count, quality)
  end

  def self.get_palette(img, color_count : Int32 = 5, quality : Int32 = 10, threads : Int32 = 0) : Array(RGB)
    validate_params(color_count, quality)
    # Prefer to operate on CrImage::Image directly; if the caller passed a
    # different type, attempt to coerce it into an image and delegate.
    if img.is_a?(CrImage::Image)
      get_palette_from_image(img.as(CrImage::Image), color_count, quality, threads)
    else
      # Try to read it using CrImage.read if possible
      begin
        begin
          read_img = CrImage.read(img)
        rescue ex : Exception
          STDERR.puts "get_palette: CrImage.read failed: #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
          read_img = nil
        end
        if read_img
          return get_palette_from_image(read_img.as(CrImage::Image), color_count, quality, threads)
        end
      rescue ex : Exception
        STDERR.puts "get_palette: unexpected error while attempting fallback read: #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
      end
      [RGB.new(0, 0, 0)]
    end
  end

  # Concrete implementation working with CrImage::Image (compile-time known type)
  def self.get_palette_from_image(image, color_count : Int32 = 5, quality : Int32 = 10, threads : Int32 = 0) : Array(RGB)
    validate_params(color_count, quality)
    # Convert image to an RGBA image via CrImage::Pipeline which provides a
    # concrete RGBA image with a contiguous `pix` buffer. This avoids compile-
    # time dispatch issues on CrImage's many image variants.
    if ENV.has_key?("PRISMATIQ_DEBUG") && ENV["PRISMATIQ_DEBUG"]
      STDERR.puts "get_palette_from_image: image.class=#{image.class} color_count=#{color_count} quality=#{quality} threads=#{threads}"
    end
    rgba_image = CrImage::Pipeline.new(image).result
    width = rgba_image.bounds.width.to_i32
    height = rgba_image.bounds.height.to_i32

    src = rgba_image.pix
    pixels = Slice(UInt8).new(src.size)
    i = 0_i32
    while i < src.size
      pixels[i] = src[i]
      i += 1
    end
    # Delegate to the buffer-based extraction now that we have an RGBA buffer.
    get_palette_from_buffer(pixels, width, height, color_count, quality, threads)
  end

  # Helper: run palette extraction directly from an RGBA buffer (Slice(UInt8)).
  # Useful for benchmarks or when you already have raw pixel data.
  def self.get_palette_from_buffer(pixels : Slice(UInt8), width : Int32, height : Int32, color_count : Int32 = 5, quality : Int32 = 10, threads : Int32 = 0) : Array(RGB)
    validate_params(color_count, quality)
    histo, total_pixels = build_histo_from_buffer(pixels, width, height, quality, threads)

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

  # Build histogram from an RGBA buffer. Returns [histo, total_pixels].
  private def self.build_histo_from_buffer(pixels : Slice(UInt8), width : Int32, height : Int32, quality : Int32, threads : Int32) : Tuple(Array(UInt32), Int32)
    histo = Array(UInt32).new(32768, 0_u32)
    total_pixels = 0

    step = quality < 1 ? 1 : quality

    if threads <= 1
      y_coord = 0
      while y_coord < height
        x_coord = 0
        while x_coord < width
          idx = (y_coord * width + x_coord) * 4
          # Safety: guard against any index calculation issues
          if idx + 3 >= pixels.size
            x_coord += step
            next
          end

          r = pixels[idx]
          g = pixels[idx + 1]
          b = pixels[idx + 2]
          a = pixels[idx + 3]

          if a >= 125
            y, i, q = quantize_yiq_from_rgb(r.to_i, g.to_i, b.to_i)
            index = VBox.to_index(y, i, q)
            histo[index] += 1_u32
            total_pixels += 1
          end

          x_coord += step
        end
        y_coord += step
      end
    else
      thread_count = threads <= 0 ? (ENV["PRISMATIQ_THREADS"]? ? ENV["PRISMATIQ_THREADS"].to_i : CPU.cores) : threads
      thread_count = [thread_count, height].min

      locals = Array(Array(UInt32) | Nil).new(thread_count, nil)
      totals = Array(Int32).new(thread_count, 0)
      workers = Array(Thread).new

      rows_per = (height + thread_count - 1) // thread_count

      t = 0
      while t < thread_count
        start_row = t * rows_per
        break if start_row >= height
        end_row = [start_row + rows_per, height].min

        local_t = t
        s_row = start_row
        e_row = end_row

        workers << Thread.new do
          local_histo = Array(UInt32).new(32768, 0_u32)
          local_count = 0

          y_coord = s_row
          while y_coord < e_row
            x_coord = 0
            while x_coord < width
              idx = (y_coord * width + x_coord) * 4
              # Safety: guard against any index calculation issues
              if idx + 3 >= pixels.size
                x_coord += step
                next
              end

              r = pixels[idx]
              g = pixels[idx + 1]
              b = pixels[idx + 2]
              a = pixels[idx + 3]

              if a >= 125
                y, i, q = quantize_yiq_from_rgb(r.to_i, g.to_i, b.to_i)
                index = VBox.to_index(y, i, q)
                if index >= 0 && index < local_histo.size
                  local_histo[index] += 1_u32
                end
                local_count += 1
              end

              x_coord += step
            end
            y_coord += step
          end

          locals[local_t] = local_histo
          totals[local_t] = local_count
        end

        t += 1
      end

      workers.each do |w|
        w.join
      end

      total_pixels = merge_locals_chunked(histo, locals)
    end

    {histo, total_pixels}
  end

  struct PaletteEntry
    property rgb : RGB
    property count : Int32
    property percent : Float64

    def initialize(@rgb : RGB, @count : Int32, @percent : Float64)
    end
  end

  # Public API: return palette entries with counts and percentages.
  def self.get_palette_with_stats_from_buffer(pixels : Slice(UInt8), width : Int32, height : Int32, color_count : Int32 = 5, quality : Int32 = 10, threads : Int32 = 0) : Tuple(Array(PaletteEntry), Int32)
    histo, total_pixels = build_histo_from_buffer(pixels, width, height, quality, threads)
    if total_pixels == 0
      return {[] of PaletteEntry, 0}
    end

    mmcq = MMCQ.new(histo)
    vboxes = mmcq.quantize(color_count)

    entries = Array(PaletteEntry).new
    vboxes.each do |box|
      next if box.count == 0
      avg_color = box.average_color
      rgb = avg_color.to_rgb_obj
      percent = box.count.to_f64 / total_pixels.to_f64
      entries << PaletteEntry.new(rgb, box.count, percent)
    end

    entries_sorted = entries.sort_by { |e| -e.count }
    {entries_sorted, total_pixels}
  end

  # Compatibility wrapper returning ColorThief-like hex array
  def self.get_palette_color_thief_from_buffer(pixels : Slice(UInt8), width : Int32, height : Int32, color_count : Int32 = 5, quality : Int32 = 10, threads : Int32 = 0) : Array(String)
    # For the ColorThief-style wrapper return deterministic results independent
    # of threading. Build stats single-threaded to ensure stable ordering.
    entries, _ = get_palette_with_stats_from_buffer(pixels, width, height, color_count, quality, 1)
    entries.map(&.rgb.to_hex)
  end

  def self.get_color(path : String) : RGB
    get_palette(path, color_count: 1, quality: 1)[0]
  end

  def self.get_color(io : IO) : RGB
    get_palette(io, color_count: 1, quality: 1)[0]
  end

  def self.get_color(img) : RGB
    get_palette(img, color_count: 1, quality: 1)[0]
  end

  private def self.sort_by_popularity(palette : Array(RGB), histo)
    palette.sort_by do |rgb|
      y = ((0.299 * rgb.r) + (0.587 * rgb.g) + (0.114 * rgb.b)).to_i
      i = ((0.596 * rgb.r) - (0.274 * rgb.g) - (0.322 * rgb.b)).to_i
      q = ((0.211 * rgb.r) - (0.523 * rgb.g) + (0.312 * rgb.b)).to_i

      y = y.clamp(0, 31)
      i = i.clamp(0, 31)
      q = q.clamp(0, 31)

      idx = VBox.to_index(y, i, q)
      count = if histo.is_a?(Hash(Int32, Int32))
                histo.fetch(idx, 0)
              else
                # histo may be Array(UInt32)
                val = histo[idx]
                if val.is_a?(UInt32)
                  val.to_i
                else
                  val
                end
              end
      -count
    end
  end

  # Merge local per-thread histograms into the master histogram using chunked
  # aggregation to improve cache locality. Returns total pixel count.
  private def self.merge_locals_chunked(histo : Array(UInt32), locals : Array(Array(UInt32) | Nil), chunk_opt : Int32? = nil) : Int32
    total = 0

    # Allow explicit override via param or env
    if chunk_opt && chunk_opt > 0
      chunk = chunk_opt
    elsif ENV["PRISMATIQ_MERGE_CHUNK"]?
      chunk = ENV["PRISMATIQ_MERGE_CHUNK"].to_i
    else
      # adaptive: use L2 cache size when available
      cache_bytes = ::PrismatIQ::CPU.l2_cache_bytes || 256 * 1024
      threads = [locals.size, 1].max
      # allocate a conservative per-thread working set
      bytes_per_chunk_target = (cache_bytes.to_f / (threads + 1)) * 0.8
      slots = (bytes_per_chunk_target / 4.0).to_i
      # clamp sensible bounds
      slots = [[slots, 64].max, 32768].min
      # round to nearest power-of-two for alignment
      chunk = 1
      while chunk < slots
        chunk <<= 1
      end
      # if we overshot, step back one
      chunk >>= 1 if chunk > slots && chunk > 64
      end

    start = 0
    if ENV["PRISMATIQ_DEBUG"]?
      STDERR.puts "merge_locals_chunked: chunk=#{chunk} threads=#{locals.size}"
    end
    while start < 32768
      ending = [start + chunk, 32768].min
      idx = start
      while idx < ending
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
