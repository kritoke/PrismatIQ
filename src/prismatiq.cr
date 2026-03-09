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


  # Quantize Y/I/Q channels into 5-bit (0..31) bins from RGB components.

  # Validation exception for invalid input parameters



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
    mmcq = Algorithm::MMCQ.new(histo, config: config)
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
          y, i, q = YIQConverter.quantize_from_rgb(r, g, b)
          histo[VBox.to_index(y, i, q)] += 1_u32
          count += 1
        end

        x_coord += step
      end
      y_coord += step
    end
    count
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

  # ============================================================================
  # NEW v2 API - Result-based with Error struct
  # ============================================================================

  # Extract palette with new Result type using Error struct
  # @param path [String] Path to the image file
  # @param options [Options] Configuration options
  # @return [Result(Array(RGB), Error)] Result containing palette or Error
  def self.get_palette_v2(path : String, options : Options = Options.default) : Result(Array(RGB), Error)
    result = get_palette(path, options)
    Result(Array(RGB), Error).ok(result)
  rescue ex : Exception
    Result(Array(RGB), Error).err(Error.file_not_found(path, ex.message || "File not found"))
  end

  # Extract palette with raising on exception on error
  # @param path [String] Path to the image file
  # @param options [Options] Configuration options
  # @return [Array(RGB)] Array of dominant colors
  # @raise [ValidationError] If options validation fails
  # @raise [Exception] If image loading or processing fails
  def self.get_palette_v2!(path : String, options : Options = Options.default) : Array(RGB)
    result = get_palette(path, options)
    result
  rescue ex : ValidationError
    raise ex
  rescue ex : Exception
    raise Exception.new("Failed to extract palette: #{ex.message}")
  end

  # Extract palette from IO with new Result type
  # @param io [IO] IO object containing image data
  # @param options [Options] Configuration options
  # @return [Result(Array(RGB), Error)] Result containing palette or Error
  def self.get_palette_v2(io : IO, options : Options = Options.default) : Result(Array(RGB), Error)
    result = get_palette(io, options)
    Result(Array(RGB), Error).ok(result)
  rescue ex : Exception
    Result(Array(RGB), Error).err(Error.corrupted_image(ex.message))
  end

  # Extract palette from buffer with new Result type
  # @param pixels [Slice(UInt8)] RGBA pixel data
  # @param width [Int32] Image width
  # @param height [Int32] Image height
  # @param options [Options] Configuration options
  # @param config [Config] Runtime configuration
  # @return [Result(Array(RGB), Error)] Result containing palette or Error
  def self.get_palette_v2(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default, config : Config = Config.default) : Result(Array(RGB), Error)
    histo, total_pixels = build_histo_from_buffer(pixels, width, height, options, config)
    return Result(Array(RGB), Error).err(Error.invalid_options("pixels", "0", "No valid pixels found")) if total_pixels == 0

    palette = quantize_palette(histo, options, config)
    Result(Array(RGB), Error).ok(palette[0...options.color_count])
  rescue ex : Exception
    Result(Array(RGB), Error).err(Error.processing_failed(ex.message || "Processing failed"))
  end

  # Channel-based async palette extraction

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

    mmcq = Algorithm::MMCQ.new(histo, config: config)
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