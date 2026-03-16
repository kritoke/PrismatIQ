require "./prismatiq/errors"
require "./prismatiq/result"
require "./prismatiq/options"
require "./prismatiq/rgb"
require "./prismatiq/utils/validation"
require "./prismatiq/utils/binary_reader"
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
require "./prismatiq/svg_color_extractor"
require "./prismatiq/theme_result"
require "./prismatiq/theme_extractor"
require "json"
require "yaml"

module PrismatIQ
  VERSION = "0.5.3"

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
  # This version removes all deprecated legacy APIs from previous versions.
  # Users must migrate to the v2 Result-based APIs or use the exception-based variants.

  # ============================================================================
  # Public API - Palette Extraction v2 (Result-based with Error struct)
  # ============================================================================

  # Extract palette from a file path with explicit error handling.
  # @param path [String] Path to the image file
  # @param options [Options] Configuration options (color_count, quality, threads, alpha_threshold)
  # @return [Result(Array(RGB), Error)] Result containing palette or structured error
  def self.get_palette_v2(path : String, options : Options = Options.default) : Result(Array(RGB), Error)
    options.validate!
    extractor = Core::PaletteExtractor.new
    result = extractor.extract_from_path(path, options)

    if result.empty?
      return Result(Array(RGB), Error).err(Error.file_not_found(path, "Failed to extract palette"))
    end

    Result(Array(RGB), Error).ok(result)
  rescue ex : ValidationError
    Result(Array(RGB), Error).err(Error.invalid_options("path", path, ex.message))
  rescue ex : Exception
    Result(Array(RGB), Error).err(Error.file_not_found(path, ex.message || "File not found"))
  end

  # Extract palette from a file path, raising exceptions on errors.
  # @param path [String] Path to the image file
  # @param options [Options] Configuration options
  # @return [Array(RGB)] Array of dominant colors
  # @raise [ValidationError] If options validation fails
  # @raise [Exception] If image loading or processing fails
  def self.get_palette_v2!(path : String, options : Options = Options.default) : Array(RGB)
    options.validate!
    extractor = Core::PaletteExtractor.new
    result = extractor.extract_from_path(path, options)

    if result.empty?
      raise Exception.new("Failed to extract palette from #{path}")
    end

    result
  end

  # Extract palette from an IO source with explicit error handling.
  # @param io [IO] IO object containing image data
  # @param options [Options] Configuration options
  # @return [Result(Array(RGB), Error)] Result containing palette or structured error
  def self.get_palette_v2(io : IO, options : Options = Options.default) : Result(Array(RGB), Error)
    options.validate!
    extractor = Core::PaletteExtractor.new
    result = extractor.extract_from_io(io, options)

    if result.empty?
      return Result(Array(RGB), Error).err(Error.corrupted_image("Failed to extract palette from IO"))
    end

    Result(Array(RGB), Error).ok(result)
  rescue ex : ValidationError
    Result(Array(RGB), Error).err(Error.invalid_options("io", "IO object", ex.message))
  rescue ex : Exception
    Result(Array(RGB), Error).err(Error.corrupted_image(ex.message || "Corrupted image"))
  end

  # Extract palette from an IO source, raising exceptions on errors.
  # @param io [IO] IO object containing image data
  # @param options [Options] Configuration options
  # @return [Array(RGB)] Array of dominant colors
  # @raise [ValidationError] If options validation fails
  # @raise [Exception] If image loading or processing fails
  def self.get_palette_v2!(io : IO, options : Options = Options.default) : Array(RGB)
    options.validate!
    extractor = Core::PaletteExtractor.new
    result = extractor.extract_from_io(io, options)

    if result.empty?
      raise Exception.new("Failed to extract palette from IO")
    end

    result
  end

  # Extract palette from raw RGBA pixel buffer with explicit error handling.
  # @param pixels [Slice(UInt8)] RGBA pixel data (4 bytes per pixel)
  # @param width [Int32] Image width in pixels
  # @param height [Int32] Image height in pixels
  # @param options [Options] Configuration options
  # @param config [Config] Runtime configuration (debugging, threading)
  # @return [Result(Array(RGB), Error)] Result containing palette or structured error
  def self.get_palette_v2(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default, config : Config = Config.default) : Result(Array(RGB), Error)
    options.validate!
    extractor = Core::PaletteExtractor.new(config)
    result = extractor.extract_from_buffer(pixels, width, height, options)

    if result.empty?
      return Result(Array(RGB), Error).err(Error.invalid_options("pixels", "0", "No valid pixels found"))
    end

    Result(Array(RGB), Error).ok(result)
  rescue ex : ValidationError
    Result(Array(RGB), Error).err(Error.invalid_options("buffer", "buffer", ex.message || "Validation failed"))
  rescue ex : Exception
    Result(Array(RGB), Error).err(Error.processing_failed(ex.message || "Processing failed"))
  end

  # Extract palette from raw RGBA pixel buffer, raising exceptions on errors.
  # @param pixels [Slice(UInt8)] RGBA pixel data
  # @param width [Int32] Image width
  # @param height [Int32] Image height
  # @param options [Options] Configuration options
  # @param config [Config] Runtime configuration
  # @return [Array(RGB)] Array of dominant colors
  # @raise [ValidationError] If options validation fails
  # @raise [Exception] If image processing fails
  def self.get_palette_v2!(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default, config : Config = Config.default) : Array(RGB)
    options.validate!
    extractor = Core::PaletteExtractor.new(config)
    result = extractor.extract_from_buffer(pixels, width, height, options)

    if result.empty?
      raise Exception.new("Failed to extract palette from buffer")
    end

    result
  end

  # Extract palette from a CrImage::Image with explicit error handling.
  # @param image [CrImage::Image] Image object
  # @param options [Options] Configuration options
  # @return [Result(Array(RGB), Error)] Result containing palette or structured error
  def self.get_palette_v2(image : CrImage::Image, options : Options = Options.default) : Result(Array(RGB), Error)
    options.validate!
    extractor = Core::PaletteExtractor.new
    result = extractor.extract_from_image(image, options)

    if result.empty?
      return Result(Array(RGB), Error).err(Error.corrupted_image("Failed to extract palette from image"))
    end

    Result(Array(RGB), Error).ok(result)
  rescue ex : ValidationError
    Result(Array(RGB), Error).err(Error.invalid_options("image", "image", ex.message))
  rescue ex : Exception
    Result(Array(RGB), Error).err(Error.corrupted_image(ex.message || "Corrupted image"))
  end

  # ============================================================================
  # Modern Options-based APIs (non-deprecated)
  # ============================================================================

  # Extract palette from raw RGBA pixel buffer using Options.
  # @param pixels [Slice(UInt8)] RGBA pixel data (4 bytes per pixel)
  # @param width [Int32] Image width in pixels
  # @param height [Int32] Image height in pixels
  # @param options [Options] Configuration options
  # @param config [Config] Runtime configuration (debugging, threading)
  # @return [Array(RGB)] Array of dominant colors
  def self.get_palette_from_buffer(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options, config : Config = Config.default) : Array(RGB)
    options.validate!
    extractor = Core::PaletteExtractor.new(config)
    extractor.extract_from_buffer(pixels, width, height, options)
  end

  # Find closest color in palette to a target color
  def self.find_closest(target : RGB, palette : Array(RGB)) : RGB?
    return if palette.empty?
    palette.min_by(&.distance_to(target))
  end

  # Find closest color in image palette to a target color
  def self.find_closest_in_palette(target : RGB, path : String, options : Options = Options.default) : RGB?
    result = get_palette_v2(path, options)
    return unless result.ok?
    find_closest(target, result.value)
  end

  # ============================================================================
  # Extended API - Convenience methods
  # ============================================================================

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

  private def self.theme_extractor : ThemeExtractor
    ThemeExtractor.instance
  end

  def self.extract_theme(source : String, options : ThemeOptions = ThemeOptions.new) : ThemeResult?
    theme_extractor.extract(source, options)
  end

  def self.fix_theme(theme_json : String, legacy_bg : String? = nil, legacy_text : String? = nil) : String?
    theme_extractor.fix_theme(theme_json, legacy_bg, legacy_text)
  end

  def self.clear_theme_cache
    theme_extractor.clear_cache
  end
end
