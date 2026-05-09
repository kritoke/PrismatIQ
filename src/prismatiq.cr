require "./prismatiq/errors"
require "./prismatiq/result"
require "./prismatiq/version"
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
require "./prismatiq/luminance_calculator"
require "./prismatiq/theme"
require "./prismatiq/theme_detector"
require "./prismatiq/config"
require "./prismatiq/core/palette_extractor"
require "./prismatiq/core/palette_convenience"
require "./prismatiq/tempfile_helper"
require "./prismatiq/bmp_parser"
require "./prismatiq/parsed_image"
require "./prismatiq/png_extractor"
require "./prismatiq/ico_entry"
require "./prismatiq/ico_file"
require "./prismatiq/svg_color_extractor"
require "./prismatiq/theme_result"
require "./prismatiq/theme_extractor"

module PrismatIQ
  @@theme_extractor : ThemeExtractor?
  @@theme_extractor_mutex = Mutex.new

  # High-performance Crystal shard for extracting dominant color palettes from images.
  #
  # ## Thread Safety
  #
  # All public API methods are safe for concurrent use from multiple Crystal fibers
  # within the same thread. Shared mutable state is protected by Mutex synchronization.
  # Note: Crystal fibers are cooperatively scheduled within a single OS thread by default.
  # The Mutex-based synchronization in this library also provides safety if you create
  # explicit OS threads, but the primary concurrency model is fiber-based.
  #
  # ## Memory Optimization
  #
  # Memory usage is controlled through:
  # - Configurable max image dimensions (`Config#max_image_width`, `Config#max_image_height`)
  # - Bounded histogram iteration in VBox computations
  # - Shared ThemeExtractor caching with configurable cache limits
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

  def self.get_palette_v2(path : String, options : Options = Options.default, config : Config = Config.default) : Result(Array(RGB), Error)
    options.validate!

    validation = Utils::Validation.validate_file_path(path)
    return Result(Array(RGB), Error).err(Error.file_not_found(path)) if validation.err?

    img = Utils::ImageLoader.read(validation.value)
    width = img.bounds.width.to_i32
    height = img.bounds.height.to_i32

    if width > config.max_image_width || height > config.max_image_height
      return Result(Array(RGB), Error).err(Error.image_too_large(width, height, config.max_image_width, config.max_image_height))
    end

    rgba_image = Utils::ImageLoader.normalize(img)
    extractor = Core::PaletteExtractor.new(config)
    result = extractor.extract_from_image_data(rgba_image, width, height, options)

    if result.empty?
      return Result(Array(RGB), Error).err(Error.file_not_found(path, "Failed to extract palette"))
    end

    Result(Array(RGB), Error).ok(result)
  rescue ex : Exception
    Result(Array(RGB), Error).err(Error.from_exception_with_path(ex, path))
  end

  def self.get_palette_v2!(path : String, options : Options = Options.default, config : Config = Config.default) : Array(RGB)
    options.validate!

    validation = Utils::Validation.validate_file_path(path)
    raise Exception.new("Failed to extract palette from #{path}") if validation.err?

    img = Utils::ImageLoader.read(validation.value)
    width = img.bounds.width.to_i32
    height = img.bounds.height.to_i32

    if width > config.max_image_width || height > config.max_image_height
      raise Exception.new("Image dimensions #{width}x#{height} exceed maximum allowed #{config.max_image_width}x#{config.max_image_height}")
    end

    rgba_image = Utils::ImageLoader.normalize(img)
    extractor = Core::PaletteExtractor.new(config)
    result = extractor.extract_from_image_data(rgba_image, width, height, options)

    if result.empty?
      raise Exception.new("Failed to extract palette from #{path}")
    end

    result
  end

  def self.get_palette_v2(io : IO, options : Options = Options.default, config : Config = Config.default) : Result(Array(RGB), Error)
    options.validate!

    img = Utils::ImageLoader.read(io)
    width = img.bounds.width.to_i32
    height = img.bounds.height.to_i32

    if width > config.max_image_width || height > config.max_image_height
      return Result(Array(RGB), Error).err(Error.image_too_large(width, height, config.max_image_width, config.max_image_height))
    end

    rgba_image = Utils::ImageLoader.normalize(img)
    extractor = Core::PaletteExtractor.new(config)
    result = extractor.extract_from_image_data(rgba_image, width, height, options)

    if result.empty?
      return Result(Array(RGB), Error).err(Error.corrupted_image("Failed to extract palette from IO"))
    end

    Result(Array(RGB), Error).ok(result)
  rescue ex : Exception
    Result(Array(RGB), Error).err(Error.from_exception_for_io(ex))
  end

  def self.get_palette_v2!(io : IO, options : Options = Options.default, config : Config = Config.default) : Array(RGB)
    options.validate!

    img = Utils::ImageLoader.read(io)
    width = img.bounds.width.to_i32
    height = img.bounds.height.to_i32

    if width > config.max_image_width || height > config.max_image_height
      raise Exception.new("Image dimensions #{width}x#{height} exceed maximum allowed #{config.max_image_width}x#{config.max_image_height}")
    end

    rgba_image = Utils::ImageLoader.normalize(img)
    extractor = Core::PaletteExtractor.new(config)
    result = extractor.extract_from_image_data(rgba_image, width, height, options)

    if result.empty?
      raise Exception.new("Failed to extract palette from IO")
    end

    result
  end

  def self.get_palette_v2(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default, config : Config = Config.default) : Result(Array(RGB), Error)
    options.validate!
    extractor = Core::PaletteExtractor.new(config)
    result = extractor.extract_from_buffer(pixels, width, height, options)

    if result.empty?
      return Result(Array(RGB), Error).err(Error.invalid_options("pixels", "0", "No valid pixels found"))
    end

    Result(Array(RGB), Error).ok(result)
  rescue ex : Exception
    Result(Array(RGB), Error).err(Error.from_exception(ex, "buffer", "buffer"))
  end

  def self.get_palette_v2!(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.default, config : Config = Config.default) : Array(RGB)
    options.validate!
    extractor = Core::PaletteExtractor.new(config)
    result = extractor.extract_from_buffer(pixels, width, height, options)

    if result.empty?
      raise Exception.new("Failed to extract palette from buffer")
    end

    result
  end

  def self.get_palette_v2(image : CrImage::Image, options : Options = Options.default, config : Config = Config.default) : Result(Array(RGB), Error)
    options.validate!

    width = image.bounds.width.to_i32
    height = image.bounds.height.to_i32

    if width > config.max_image_width || height > config.max_image_height
      return Result(Array(RGB), Error).err(Error.image_too_large(width, height, config.max_image_width, config.max_image_height))
    end

    rgba_image = Utils::ImageLoader.normalize(image)
    extractor = Core::PaletteExtractor.new(config)
    result = extractor.extract_from_image_data(rgba_image, width, height, options)

    if result.empty?
      return Result(Array(RGB), Error).err(Error.corrupted_image("Failed to extract palette from image"))
    end

    Result(Array(RGB), Error).ok(result)
  rescue ex : Exception
    Result(Array(RGB), Error).err(Error.from_exception(ex, "image", "image"))
  end

  # ============================================================================
  # Modern Options-based APIs (non-deprecated)
  # ============================================================================

  def self.get_palette_from_buffer(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options, config : Config = Config.default) : Array(RGB)
    options.validate!
    extractor = Core::PaletteExtractor.new(config)
    extractor.extract_from_buffer(pixels, width, height, options)
  end

  def self.find_closest(target : RGB, palette : Array(RGB)) : RGB?
    return if palette.empty?
    palette.min_by(&.distance_to(target))
  end

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

  def self.get_color(path : String) : RGB?
    Core::PaletteConvenience.new.get_color_from_path(path)
  end

  def self.get_color(io : IO) : RGB?
    Core::PaletteConvenience.new.get_color_from_io(io)
  end

  def self.get_color(img : CrImage::Image) : RGB?
    Core::PaletteConvenience.new.get_color(img)
  end

  def self.extract_theme(source : String, options : ThemeOptions = ThemeOptions.new) : ThemeResult?
    shared_theme_extractor.extract(source, options)
  end

  def self.fix_theme(theme_json : String, legacy_bg : String? = nil, legacy_text : String? = nil) : String?
    shared_theme_extractor.fix_theme(theme_json, legacy_bg, legacy_text)
  end

  def self.clear_caches
    @@theme_extractor_mutex.synchronize do
      @@theme_extractor.try(&.clear_cache)
    end
  end

  def self.clear_theme_cache
    clear_caches
  end

  private def self.shared_theme_extractor : ThemeExtractor
    @@theme_extractor_mutex.synchronize do
      @@theme_extractor ||= ThemeExtractor.new
    end
  end

  def self.log_debug(message : String) : Nil
    STDERR.puts message if ENV["PRISMATIQ_DEBUG"]?
  end
end
