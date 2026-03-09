require "./cpu_cores"
require "./prismatiq/types"
require "./prismatiq/algorithm/priority_queue"
require "./prismatiq/algorithm/mmcq"
require "./prismatiq/thread_safe_cache"
require "./prismatiq/yiq_converter"
require "./prismatiq/color_extractor"
require "./prismatiq/accessibility"
require "./prismatiq/theme"
require "./prismatiq/config"
require "./prismatiq/result"
require "./prismatiq/options"
require "./prismatiq/rgb"
require "crimage"
require "./prismatiq/tempfile_helper"
require "./prismatiq/bmp_parser"
require "./prismatiq/ico"
require "json"
require "yaml"

module PrismatIQ
  VERSION = "0.4.1"

  module Constants
    ALPHA_THRESHOLD_DEFAULT = 125_u8
    HISTOGRAM_SIZE          =  32768
    RGBA_CHANNELS           =      4

    # Luminance threshold for theme detection (0.5 = midpoint)
    LUMINANCE_THRESHOLD = 0.5

    # WCAG 2.1 Contrast Ratio Constants
    module WCAG
      CONTRAST_RATIO_AA        = 4.5 # Minimum for normal text (AA)
      CONTRAST_RATIO_AA_LARGE  = 3.0 # Minimum for large text (AA Large)
      CONTRAST_RATIO_AAA       = 7.0 # Minimum for normal text (AAA)
      CONTRAST_RATIO_AAA_LARGE = 4.5 # Minimum for large text (AAA Large)
    end

    module YIQ
      Y_FROM_R =  0.299
      Y_FROM_G =  0.587
      Y_FROM_B =  0.114
      I_FROM_R =  0.596
      I_FROM_G = -0.274
      I_FROM_B = -0.322
      Q_FROM_R =  0.211
      Q_FROM_G = -0.523
      Q_FROM_B =  0.312

      R_FROM_Y =    1.0
      R_FROM_I =  0.956
      R_FROM_Q =  0.621
      G_FROM_Y =    1.0
      G_FROM_I = -0.272
      G_FROM_Q = -0.647
      B_FROM_Y =    1.0
      B_FROM_I = -1.106
      B_FROM_Q =  1.703
    end
  end

  # Result type for palette extraction with success/failure information
  struct PaletteResult
    getter colors : Array(RGB)
    getter? success : Bool
    getter error : String?
    getter total_pixels : Int32

    def initialize(@colors : Array(RGB), @success : Bool, @error : String?, @total_pixels : Int32)
    end

    def self.ok(colors : Array(RGB), total_pixels : Int32) : PaletteResult
      new(colors, true, nil, total_pixels)
    end

    def self.err(message : String) : PaletteResult
      new([] of RGB, false, message, 0)
    end
  end

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

    # Converts from quantized YIQ values (0-31) to RGB.
    # This is used by VBox.average_color which operates on quantized histogram bins.
    def to_rgb_from_quantized : Tuple(Int32, Int32, Int32)
      # Scale quantized values back to full YIQ range
      # Y: [0, 31] -> [0, 255]
      # I: [0, 31] -> [-152, 152]
      # Q: [0, 31] -> [-134, 134]
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

  # Quantize Y/I/Q channels into 5-bit (0..31) bins from RGB components.
  private def self.quantize_yiq_from_rgb(r : Int32, g : Int32, b : Int32) : Tuple(Int32, Int32, Int32)
    YIQConverter.quantize_from_rgb(r, g, b)
  end

  # Validation exception for invalid input parameters
  class ValidationError < Exception
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
        # Return Color with quantized values - the to_rgb_from_quantized method
        # should be used when converting to RGB
        Color.new(y_sum / found, i_sum / found, q_sum / found)
      else
        Color.new(0, 0, 0)
      end
    end

    # Returns the average color as RGB, properly converting from quantized YIQ values
    def average_color_rgb : RGB
      if @count == 0
        return RGB.new(0, 0, 0)
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
        # Create Color with quantized values and convert using quantized method
        color = Color.new(y_sum / found, i_sum / found, q_sum / found)
        r, g, b = color.to_rgb_from_quantized
        RGB.new(r, g, b)
      else
        RGB.new(0, 0, 0)
      end
    end

    def split : Tuple(VBox, VBox)
      axis = find_split_axis
      return {self, VBox.new(0, 0, 0, 0, 0, 0)} if axis == -1

      indices = get_indices(axis)
      indices.sort!

      # Split at the median position - box1 gets indices 0 to mid-1, box2 gets mid to end
      mid = indices.size // 2
      return {self, VBox.new(0, 0, 0, 0, 0, 0)} if mid == 0

      # Use the value just before the median as the split point
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

      # Return new boxes with computed counts
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
      log_debug_initial(initial_box)

      pq = PriorityQueue(VBox).new(&box_comparator)
      pq.push(initial_box)

      iteration = 0
      while pq.size < max_colors && iteration < MAX_ITERATIONS
        iteration += 1
        log_debug_iteration(iteration, pq.size)

        box = pq.pop
        break unless box
        log_debug_popped_box(box)

        vbox1, vbox2 = box.split

        if vbox1 == box
          pq.push(box)
          break
        end

        log_debug_split_result(vbox1, vbox2)

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
      if @config.debug?
        puts "MMCQ: total=#{@total} initial_box.count=#{initial_box.count}"
      end
    end

    private def log_debug_iteration(iteration : Int32, pq_size : Int32)
      if @config.debug?
        puts "MMCQ iter=#{iteration} pq_size=#{pq_size}"
      end
    end

    private def log_debug_popped_box(box : VBox?)
      if @config.debug?
        puts box ? "MMCQ popped box count=#{box.count}" : "MMCQ popped nil box"
      end
    end

    private def log_debug_split_result(vbox1 : VBox, vbox2 : VBox)
      if @config.debug?
        puts "MMCQ split -> vbox1.count=#{vbox1.count} vbox2.count=#{vbox2.count}"
      end
    end

    private def collect_final_boxes(pq : PriorityQueue(VBox)) : Array(VBox)
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

  # ============================================================================
  # Public API - Palette Extraction
  # All public methods use the Options struct as the single source of truth
  # for extraction parameters (color_count, quality, threads, alpha_threshold).
  # ============================================================================

  # Extract palette from a file path.
  # @param path [String] Path to the image file
  # @param options [Options] Configuration options (color_count, quality, threads, alpha_threshold)
  # @return [Array(RGB)] Array of dominant colors
  def self.get_palette(path : String, options : Options = Options.default) : Array(RGB)
    options.validate!
    if Config.default.debug?
      STDERR.puts "get_palette(path): path=#{path} options=#{options.inspect}"
    end
    img = CrImage.read(path)
    get_palette_from_image(img.as(CrImage::Image), options)
  end

  # Extract palette from an IO source.
  # @param io [IO] IO object containing image data
  # @param options [Options] Configuration options
  # @return [Array(RGB)] Array of dominant colors
  def self.get_palette(io : IO, options : Options = Options.default) : Array(RGB)
    options.validate!
    img = CrImage.read(io)
    get_palette_from_image(img.as(CrImage::Image), options)
  end

  # Extract palette from an image object.
  # @param img [CrImage::Image | String | IO] Image source (CrImage::Image, file path, or IO)
  # @param options [Options] Configuration options
  # @return [Array(RGB)] Array of dominant colors
  def self.get_palette(img, options : Options = Options.default) : Array(RGB)
    options.validate!
    # Prefer to operate on CrImage::Image directly; if the caller passed a
    # different type, attempt to coerce it into an image and delegate.
    if img.is_a?(CrImage::Image)
      get_palette_from_image(img.as(CrImage::Image), options)
    else
      # Try to read it using CrImage.read if possible
      begin
        begin
          read_img = CrImage.read(img)
        rescue ex : Exception
          STDERR.puts "get_palette: CrImage.read failed: #{ex.message}" if Config.default.debug?
          read_img = nil
        end
        if read_img
          return get_palette_from_image(read_img.as(CrImage::Image), options)
        end
      rescue ex : Exception
        STDERR.puts "get_palette: unexpected error while attempting fallback read: #{ex.message}" if Config.default.debug?
      end
      [RGB.new(0, 0, 0)]
    end
  end

  # Extract palette from raw RGBA pixel buffer.
  # @param pixels [Slice(UInt8)] RGBA pixel data (4 bytes per pixel)
  # @param width [Int32] Image width in pixels
  # @param height [Int32] Image height in pixels
  # @param options [Options] Configuration options
  # @param config [Config] Runtime configuration (debugging, threading)
  # @return [Array(RGB)] Array of dominant colors
  def self.get_palette(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default, config : Config = Config.default) : Array(RGB)
    options.validate!
    get_palette_from_buffer(pixels, width, height, options, config)
  end

  # Concrete implementation working with CrImage::Image (compile-time known type)
  # Uses Options as single source of truth for all extraction parameters.
  def self.get_palette_from_image(image, options : Options, config : Config = Config.default) : Array(RGB)
    options.validate!
    # Convert image to an RGBA image via CrImage::Pipeline which provides a
    # concrete RGBA image with a contiguous `pix` buffer. This avoids compile-
    # time dispatch issues on CrImage's many image variants.
    if config.debug?
      STDERR.puts "get_palette_from_image: image.class=#{image.class} options=#{options.inspect}"
    end
    rgba_image = CrImage::Pipeline.new(image).result
    width = rgba_image.bounds.width.to_i32
    height = rgba_image.bounds.height.to_i32

    src = rgba_image.pix
    pixels = Slice.new(src.size) { |i| src[i] }
    # Delegate to the buffer-based extraction now that we have an RGBA buffer.
    get_palette_from_buffer(pixels, width, height, options, config)
  end

  # Helper: run palette extraction directly from an RGBA buffer (Slice(UInt8)).
  # Useful for benchmarks or when you already have raw pixel data.
  # Uses Options as single source of truth for all extraction parameters.
  def self.get_palette_from_buffer(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options, config : Config = Config.default) : Array(RGB)
    options.validate!
    histo, total_pixels = build_histo_from_buffer(pixels, width, height, options, config)

    if total_pixels == 0
      return [RGB.new(0, 0, 0)]
    end

    quantize_palette(histo, options, config)[0...options.color_count]
  end

  # Backward-compatible overload with keyword arguments
  @[Deprecated("Use `get_palette(pixels, width, height, options)` with Options instead")]
  def self.get_palette_from_buffer(pixels : Slice(UInt8), width : Int32, height : Int32, color_count : Int32 = 5, quality : Int32 = 10, threads : Int32 = 0, config : Config = Config.default) : Array(RGB)
    options = Options.new(color_count, quality, threads)
    get_palette_from_buffer(pixels, width, height, options, config)
  end

  private def self.quantize_palette(histo : Array(UInt32), options : Options, config : Config = Config.default) : Array(RGB)
    mmcq = MMCQ.new(histo, config: config)
    vboxes = mmcq.quantize(options.color_count)

    palette = vboxes.compact_map do |box|
      next if box.count == 0
      box.average_color_rgb
    end

    sort_by_popularity(palette, histo)
  end

  # Build histogram from an RGBA buffer using Options as single source of truth.
  # Returns [histo, total_pixels].
  private def self.build_histo_from_buffer(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options, config : Config = Config.default) : Tuple(Array(UInt32), Int32)
    histo = Array(UInt32).new(Constants::HISTOGRAM_SIZE, 0_u32)
    step = options.quality < 1 ? 1 : options.quality
    alpha_threshold = options.alpha_threshold

    if options.threads <= 1
      total_pixels = process_pixel_range(pixels, width, 0, height, step, alpha_threshold, histo)
    else
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
          local_count = process_pixel_range(pixels, width, start_row, end_row, step, alpha_threshold, local_histo)
          locals[local_idx] = local_histo
          totals[local_idx] = local_count
        end
      end

      workers.each(&.join)
      total_pixels = merge_locals_chunked(histo, locals, config)
    end

    {histo, total_pixels}
  end

  @[AlwaysInline]
  private def self.process_pixel_range(pixels : Slice(UInt8), width : Int32, start_row : Int32, end_row : Int32, step : Int32, alpha_threshold : UInt8, histo : Array(UInt32)) : Int32
    count = 0
    y_coord = start_row
    while y_coord < end_row
      x_coord = 0
      while x_coord < width
        idx = (y_coord * width + x_coord) * 4
        break if idx + 3 >= pixels.size

        a = pixels[idx + 3]
        if a >= alpha_threshold
          r = pixels[idx].to_i
          g = pixels[idx + 1].to_i
          b = pixels[idx + 2].to_i
          y, i, q = quantize_yiq_from_rgb(r, g, b)
          histo[VBox.to_index(y, i, q)] += 1_u32
          count += 1
        end

        x_coord += step
      end
      y_coord += step
    end
    count
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

  # Find closest color in palette to a target color
  def self.find_closest(target : RGB, palette : Array(RGB)) : RGB?
    return if palette.empty?
    palette.min_by(&.distance_to(target))
  end

  # Find closest color in image palette to a target color
  def self.find_closest_in_palette(target : RGB, path : String, options : Options = Options.default) : RGB?
    palette = get_palette(path, options)
    find_closest(target, palette)
  end

  # ============================================================================
  # Extended API - Result-based and Stats variants
  # These provide additional functionality while still using Options.
  # ============================================================================

  # Get palette result with success/failure information
  # @param path [String] Path to the image file
  # @param options [Options] Configuration options
  # @return [PaletteResult] Result containing colors, success status, and error message
  def self.get_palette_result(path : String, options : Options = Options.default) : PaletteResult
    options.validate!
    colors = get_palette(path, options)
    PaletteResult.ok(colors, 0)
  rescue ex : Exception
    PaletteResult.err(ex.message || "Unknown error")
  end

  # Get palette result from IO source
  # @param io [IO] IO object containing image data
  # @param options [Options] Configuration options
  # @return [PaletteResult] Result containing colors, success status, and error message
  def self.get_palette_result(io : IO, options : Options = Options.default) : PaletteResult
    options.validate!
    colors = get_palette(io, options)
    PaletteResult.ok(colors, 0)
  rescue ex : Exception
    PaletteResult.err(ex.message || "Unknown error")
  end

  # Get palette result from raw pixel buffer
  # @param pixels [Slice(UInt8)] RGBA pixel data
  # @param width [Int32] Image width
  # @param height [Int32] Image height
  # @param options [Options] Configuration options
  # @param config [Config] Runtime configuration
  # @return [PaletteResult] Result containing colors, success status, and error message
  def self.get_palette_result(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default, config : Config = Config.default) : PaletteResult
    options.validate!
    histo, total_pixels = build_histo_from_buffer(pixels, width, height, options, config)
    if total_pixels == 0
      return PaletteResult.err("No valid pixels found")
    end

    palette = quantize_palette(histo, options, config)
    PaletteResult.ok(palette[0...options.color_count], total_pixels)
  rescue ex : Exception
    PaletteResult.err(ex.message || "Unknown error")
  end

  # Extract palette with explicit error handling using Result type
  # @param path [String] Path to the image file
  # @param options [Options] Configuration options
  # @return [Result(Array(RGB), String)] Result containing palette or error message
  def self.get_palette_or_error(path : String, options : Options = Options.default) : Result(Array(RGB), String)
    options.validate!
    Result(Array(RGB), String).ok(get_palette(path, options))
  rescue ex : Exception
    Result(Array(RGB), String).err(ex.message || "Unknown error")
  end

  # Extract palette from IO with explicit error handling using Result type
  # @param io [IO] IO object containing image data
  # @param options [Options] Configuration options
  # @return [Result(Array(RGB), String)] Result containing palette or error message
  def self.get_palette_or_error(io : IO, options : Options = Options.default) : Result(Array(RGB), String)
    options.validate!
    Result(Array(RGB), String).ok(get_palette(io, options))
  rescue ex : Exception
    Result(Array(RGB), String).err(ex.message || "Unknown error")
  end

  # Extract palette from buffer with explicit error handling using Result type
  # @param pixels [Slice(UInt8)] RGBA pixel data
  # @param width [Int32] Image width
  # @param height [Int32] Image height
  # @param options [Options] Configuration options
  # @param config [Config] Runtime configuration
  # @return [Result(Array(RGB), String)] Result containing palette or error message
  def self.get_palette_or_error(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default, config : Config = Config.default) : Result(Array(RGB), String)
    options.validate!
    histo, total_pixels = build_histo_from_buffer(pixels, width, height, options, config)
    return Result(Array(RGB), String).err("No valid pixels found") if total_pixels == 0

    palette = quantize_palette(histo, options, config)
    Result(Array(RGB), String).ok(palette[0...options.color_count])
  rescue ex : Exception
    Result(Array(RGB), String).err(ex.message || "Unknown error")
  end

  # Fiber-based async palette extraction
  # @param path [String] Path to the image file
  # @param options [Options] Configuration options
  # @param &block [Proc(Array(RGB), Nil)] Callback block invoked with the palette result
  def self.get_palette_async(path : String, options : Options = Options.default, &block : Array(RGB) ->)
    spawn do
      begin
        result = get_palette(path, options)
        block.call(result)
      rescue
        block.call([RGB.new(0, 0, 0)])
      end
    end
  end

  # Channel-based async palette extraction
  # @param path [String] Path to the image file
  # @param options [Options] Configuration options
  # @return [Channel(Array(RGB))] Channel that will receive the palette
  def self.get_palette_channel(path : String, options : Options = Options.default) : Channel(Array(RGB))
    ch = Channel(Array(RGB)).new(1)
    spawn do
      begin
        ch.send(get_palette(path, options))
      rescue
        ch.send([RGB.new(0, 0, 0)])
      end
    end
    ch
  end

  # Extract palette with detailed statistics (counts and percentages)
  # @param pixels [Slice(UInt8)] RGBA pixel data
  # @param width [Int32] Image width
  # @param height [Int32] Image height
  # @param options [Options] Configuration options
  # @param config [Config] Runtime configuration
  # @return [Tuple(Array(PaletteEntry), Int32)] Tuple of palette entries with stats and total pixel count
  def self.get_palette_with_stats(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default, config : Config = Config.default) : Tuple(Array(PaletteEntry), Int32)
    histo, total_pixels = build_histo_from_buffer(pixels, width, height, options, config)
    if total_pixels == 0
      return {[] of PaletteEntry, 0}
    end

    mmcq = MMCQ.new(histo, config: config)
    vboxes = mmcq.quantize(options.color_count)

    entries = vboxes.compact_map do |box|
      next if box.count == 0
      rgb = box.average_color_rgb
      percent = box.count.to_f64 / total_pixels.to_f64
      PaletteEntry.new(rgb, box.count, percent)
    end.sort_by!(&.count).reverse!

    {entries, total_pixels}
  end

  # Compatibility wrapper returning ColorThief-like hex array
  # @param pixels [Slice(UInt8)] RGBA pixel data
  # @param width [Int32] Image width
  # @param height [Int32] Image height
  # @param options [Options] Configuration options
  # @return [Array(String)] Array of hex color strings
  def self.get_palette_color_thief(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default) : Array(String)
    # For the ColorThief-style wrapper return deterministic results independent
    # of threading. Build stats single-threaded to ensure stable ordering.
    single_threaded_options = options.with_threads(1)
    entries, _ = get_palette_with_stats(pixels, width, height, single_threaded_options)
    entries.map(&.rgb.to_hex)
  end

  # ============================================================================
  # Convenience Methods - Single color extraction
  # ============================================================================

  # Extract a single dominant color from a file path
  # @param path [String] Path to the image file
  # @return [RGB] The dominant color
  def self.get_color(path : String) : RGB
    get_palette(path, Options.default.with_color_count(1).with_quality(1))[0]
  end

  # Extract a single dominant color from IO
  # @param io [IO] IO object containing image data
  # @return [RGB] The dominant color
  def self.get_color(io : IO) : RGB
    get_palette(io, Options.default.with_color_count(1).with_quality(1))[0]
  end

  # Extract a single dominant color from an image
  # @param img [CrImage::Image | String | IO] Image source
  # @return [RGB] The dominant color
  def self.get_color(img) : RGB
    get_palette(img, Options.default.with_color_count(1).with_quality(1))[0]
  end

  private def self.sort_by_popularity(palette : Array(RGB), histo)
    palette.sort_by do |rgb|
      y, i, q = YIQConverter.quantize_from_rgb(rgb.r, rgb.g, rgb.b)
      idx = YIQConverter.to_index(y, i, q)
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
  private def self.merge_locals_chunked(histo : Array(UInt32), locals : Array(Array(UInt32)?), config : Config) : Int32
    total = 0

    chunk = config.merge_chunk.nil? ? nil : config.merge_chunk
    if chunk.nil?
      # adaptive: use L2 cache size when available
      cache_bytes = ::PrismatIQ::CPU.l2_cache_bytes || 256 * 1024
      threads = [locals.size, 1].max
      # allocate a conservative per-thread working set
      bytes_per_chunk_target = (cache_bytes.to_f / (threads + 1)) * 0.8
      slots = (bytes_per_chunk_target / 4.0).to_i
      # clamp sensible bounds
      slots = [[slots, 64].max, Constants::HISTOGRAM_SIZE].min
      # round to nearest power-of-two for alignment
      chunk = 1
      while chunk < slots
        chunk <<= 1
      end
      # if we overshot, step back one
      chunk >>= 1 if chunk > slots && chunk > 64
    end

    start = 0
    if config.debug?
      STDERR.puts "merge_locals_chunked: chunk=#{chunk} threads=#{locals.size}"
    end
    while start < Constants::HISTOGRAM_SIZE
      ending = [start + chunk, Constants::HISTOGRAM_SIZE].min
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
