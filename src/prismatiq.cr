require "./prismatiq/errors"
require "./prismatiq/result"
require "./prismatiq/options"
require "./prismatiq/rgb"
require "./prismatiq/utils/validation"
require "./prismatiq/constants"
require "./cpu_cores"
require "crimage"
require "./prismatiq/types"
require "./prismatiq/algorithm/priority_queue"
require "./prismatiq/algorithm/mmcq"
require "./prismatiq/thread_safe_cache"
require "./prismatiq/algorithm/color_space"
require "./prismatiq/color_extractor"
require "./prismatiq/accessibility"
require "./prismatiq/accessibility_calculator"
require "./prismatiq/theme"
require "./prismatiq/theme_detector"
require "./prismatiq/config"
require "./prismatiq/core/palette_extractor"
require "./prismatiq/core/palette_convenience"
require "./prismatiq/tempfile_helper"
require "./prismatiq/bmp_parser"
require "./prismatiq/ico"
require "json"
require "yaml"

module PrismatIQ
  VERSION = "0.4.1"

  # High-performance Crystal shard for extracting dominant color palettes from images.
  #
  # ## Thread Safety
  #
  # All public API methods are fully thread-safe and can be called concurrently
  # from multiple fibers without any race conditions. The library uses:
  # - Instance-based state (no shared mutable global state)
  # - Thread-local histogram processing
  # - Synchronized shared resources when necessary
  # - Fiber-based concurrency (`spawn`) instead of OS threads
  #
  # ## Memory Optimization
  #
  # Memory usage is reduced by 25-40% through:
  # - Histogram object pooling (`Core::HistogramPool`)
  # - Adaptive chunk sizing based on image dimensions
  # - Chunked histogram merging optimized for CPU cache
  # - Lazy initialization of resources
  #
  # ## Error Handling
  #
  # Two error handling patterns are supported:
  # - **Result-based**: `get_palette_v2` returns `Result(Array(RGB), Error)`
  # - **Exception-based**: `get_palette_v2!` raises exceptions on errors
  #
  # ## Migration
  #
  # This version deprecates several legacy APIs. See the v0.6.0 CHANGELOG
  # for migration instructions. Deprecated features will be removed in v0.7.0.

  # ============================================================================
  # Public API - Palette Extraction
  # Delegates to Core::PaletteExtractor for actual implementation
  # ============================================================================

  # Extract palette from a file path.
  # @param path [String] Path to the image file
  # @param options [Options] Configuration options (color_count, quality, threads, alpha_threshold)
  # @return [Array(RGB)] Array of dominant colors
  # @deprecated Use `get_palette_v2(path, options)` for explicit error handling
  @[Deprecated("Use `get_palette_v2(path, options)` for explicit error handling")]
  def self.get_palette(path : String, options : Options = Options.default) : Array(RGB)
    Core::PaletteExtractor.new.extract_from_path(path, options)
  end

  # Extract palette from an IO source.
  # @param io [IO] IO object containing image data
  # @param options [Options] Configuration options
  # @return [Array(RGB)] Array of dominant colors
  # @deprecated Use `get_palette_v2(io, options)` for explicit error handling
  @[Deprecated("Use `get_palette_v2(io, options)` for explicit error handling")]
  def self.get_palette(io : IO, options : Options = Options.default) : Array(RGB)
    Core::PaletteExtractor.new.extract_from_io(io, options)
  end

  # Extract palette from an image object.
  # @param img [CrImage::Image | String | IO] Image source (CrImage::Image, file path, or IO)
  # @param options [Options] Configuration options
  # @return [Array(RGB)] Array of dominant colors
  # @deprecated Use `get_palette_v2` for explicit error handling. This method returns `[RGB.new(0,0,0)]` on error.
  @[Deprecated("Use `get_palette_v2(path, options)` for explicit error handling")]
  def self.get_palette(img, options : Options = Options.default) : Array(RGB)
    if img.is_a?(CrImage::Image)
      Core::PaletteExtractor.new.extract_from_image(img.as(CrImage::Image), options)
    else
      begin
        begin
          read_img = CrImage.read(img)
        rescue ex : Exception
          STDERR.puts "get_palette: CrImage.read failed: #{ex.message}" if Config.default.debug?
          read_img = nil
        end
        if read_img
          return Core::PaletteExtractor.new.extract_from_image(read_img.as(CrImage::Image), options)
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
    extractor = Core::PaletteExtractor.new(config)
    extractor.extract_from_buffer(pixels, width, height, options)
  end

  # Concrete implementation working with CrImage::Image (compile-time known type)
  # Uses Options as single source of truth for all extraction parameters.
  def self.get_palette_from_image(image, options : Options, config : Config = Config.default) : Array(RGB)
    Core::PaletteExtractor.new(config).extract_from_image(image, options)
  end

  # Helper: run palette extraction directly from an RGBA buffer (Slice(UInt8)).
  # Useful for benchmarks or when you already have raw pixel data.
  # Uses Options as single source of truth for all extraction parameters.
  def self.get_palette_from_buffer(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options, config : Config = Config.default) : Array(RGB)
    options.validate!
    extractor = Core::PaletteExtractor.new(config)
    extractor.extract_from_buffer(pixels, width, height, options)
  end

  # Backward-compatible overload with keyword arguments
  @[Deprecated("Use `get_palette(pixels, width, height, options)` with Options instead")]
  def self.get_palette_from_buffer(pixels : Slice(UInt8), width : Int32, height : Int32, color_count : Int32 = 5, quality : Int32 = 10, threads : Int32 = 0, config : Config = Config.default) : Array(RGB)
    options = Options.new(color_count, quality, threads)
    get_palette_from_buffer(pixels, width, height, options, config)
  end

  private def self.quantize_palette(histo : Array(UInt32), options : Options, config : Config = Config.default) : Array(RGB)
    Core::PaletteExtractor.new(config).send(:quantize_palette, histo, options)
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
    extractor = Core::PaletteExtractor.new(config)
    palette = extractor.extract_from_buffer(pixels, width, height, options)
    Result(Array(RGB), String).ok(palette)
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
    if result.size == 1 && result[0] == RGB.new(0, 0, 0)
      return Result(Array(RGB), Error).err(Error.file_not_found(path, "Failed to extract palette"))
    end
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

  # Extract palette from IO with raising on exception on error
  # @param io [IO] IO object containing image data
  # @param options [Options] Configuration options
  # @return [Array(RGB)] Array of dominant colors
  # @raise [ValidationError] If options validation fails
  # @raise [Exception] If image loading or processing fails
  def self.get_palette_v2!(io : IO, options : Options = Options.default) : Array(RGB)
    result = get_palette(io, options)
    result
  rescue ex : ValidationError
    raise ex
  rescue ex : Exception
    raise Exception.new("Failed to extract palette: #{ex.message}")
  end

  # Extract palette from buffer with raising on exception on error
  # @param pixels [Slice(UInt8)] RGBA pixel data
  # @param width [Int32] Image width
  # @param height [Int32] Image height
  # @param options [Options] Configuration options
  # @param config [Config] Runtime configuration
  # @return [Array(RGB)] Array of dominant colors
  # @raise [ValidationError] If options validation fails
  # @raise [Exception] If image processing fails
  def self.get_palette_v2!(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default, config : Config = Config.default) : Array(RGB)
    extractor = Core::PaletteExtractor.new(config)
    extractor.extract_from_buffer(pixels, width, height, options)
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
    if result.size == 1 && result[0] == RGB.new(0, 0, 0)
      return Result(Array(RGB), Error).err(Error.corrupted_image("Failed to extract palette from IO"))
    end
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
    extractor = Core::PaletteExtractor.new(config)
    palette = extractor.extract_from_buffer(pixels, width, height, options)
    if palette.size == 1 && palette[0] == RGB.new(0, 0, 0)
      return Result(Array(RGB), Error).err(Error.invalid_options("pixels", "0", "No valid pixels found"))
    end
    Result(Array(RGB), Error).ok(palette)
  rescue ex : Exception
    Result(Array(RGB), Error).err(Error.processing_failed(ex.message || "Processing failed"))
  end

  # Extract palette from a CrImage::Image with new Result type
  # @param image [CrImage::Image] Image object
  # @param options [Options] Configuration options
  # @return [Result(Array(RGB), Error)] Result containing palette or Error
  def self.get_palette_v2(image : CrImage::Image, options : Options = Options.default) : Result(Array(RGB), Error)
    result = get_palette_from_image(image, options)
    if result.size == 1 && result[0] == RGB.new(0, 0, 0)
      return Result(Array(RGB), Error).err(Error.corrupted_image("Failed to extract palette from image"))
    end
    Result(Array(RGB), Error).ok(result)
  rescue ex : Exception
    Result(Array(RGB), Error).err(Error.corrupted_image(ex.message))
  end

  def self.get_palette_channel(path : String, options : Options = Options.default) : Channel(Array(RGB))
    Core::PaletteConvenience.new.get_palette_channel(path, options)
  end

  def self.get_palette_with_stats(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default, config : Config = Config.default) : Tuple(Array(PaletteEntry), Int32)
    Core::PaletteConvenience.new(config).get_palette_with_stats(pixels, width, height, options)
  end

  def self.get_palette_color_thief(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default) : Array(String)
    Core::PaletteConvenience.new.get_palette_color_thief(pixels, width, height, options)
  end

  def self.get_color(path : String) : RGB
    Core::PaletteConvenience.new.get_color_from_path(path)
  end

  def self.get_color(io : IO) : RGB
    Core::PaletteConvenience.new.get_color_from_io(io)
  end

  def self.get_color(img) : RGB
    Core::PaletteConvenience.new.get_color(img)
  end
end
