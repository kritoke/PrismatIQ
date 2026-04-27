require "./utils/binary_reader"
require "./tempfile_helper"
require "crimage"

module PrismatIQ
  # PNGExtractor: Helper for extracting PNG-encoded image data from ICO entries
  #
  # Modern ICO files often contain PNG-compressed images instead of traditional
  # BMP/DIB data. This class provides a clean interface to decode PNG data
  # extracted from ICO entries.
  #
  # ## Features
  #
  # - Decodes PNG data embedded in ICO files to RGBA pixels
  # - Uses CrImage for PNG decoding
  # - Provides both buffer and file-based decoding paths
  # - Size validation to prevent DoS from oversized embedded images
  #
  # ## Usage
  #
  # ```
  # extractor = PNGExtractor.new(png_bytes)
  # if extractor.valid?
  #   image = extractor.to_image
  #   puts "Decoded PNG: #{image.width}x#{image.height}"
  # end
  # ```
  class PNGExtractor
    include BinaryReader

    # Maximum allowed PNG size in bytes (50 MB default)
    MAX_PNG_SIZE = 50_000_000_i64

    getter? valid : Bool
    getter width : Int32
    getter height : Int32

    def initialize(@data : Slice(UInt8), @config : Config = Config.default)
      @valid = false
      @width = 0
      @height = 0
      @pixels = Slice(UInt8).new(0)

      decode_png
    end

    def valid?
      @valid
    end

    def to_rgba : Slice(UInt8)
      raise PNGExtractError.new("Invalid PNG data") unless @valid
      @pixels
    end

    def to_image : ParsedImage
      raise PNGExtractError.new("Invalid PNG data") unless @valid
      ParsedImage.new(@width, @height, @pixels)
    end

    def self.from_slice?(data : Slice(UInt8)) : PNGExtractor?
      extractor = new(data)
      extractor.valid? ? extractor : nil
    rescue
      nil
    end

    def self.extract_from_ico(ico_data : Slice(UInt8), max_size : Int64 = MAX_PNG_SIZE) : PNGExtractor?
      return if ico_data.size < 6

      reserved = ico_data[0].to_u16 | (ico_data[1].to_u16 << 8)
      typ = ico_data[2].to_u16 | (ico_data[3].to_u16 << 8)
      count = ico_data[4].to_u16 | (ico_data[5].to_u16 << 8)

      return if reserved != 0 || (typ != 1 && typ != 2) || count <= 0

      entry_base = 6
      i = 0
      while i < count && (entry_base + i * 16 + 16) <= ico_data.size
        png_extractor = try_png_entry_at(ico_data, entry_base, i, max_size)
        return png_extractor if png_extractor
        i += 1
      end

      nil
    end

    private def self.try_png_entry_at(ico_data : Slice(UInt8), entry_base : Int32, index : Int32, max_size : Int64) : PNGExtractor?
      off = entry_base + index * 16

      size = ico_data[off + 8].to_u64 |
             (ico_data[off + 9].to_u64 << 8) |
             (ico_data[off + 10].to_u64 << 16) |
             (ico_data[off + 11].to_u64 << 24)

      image_offset = ico_data[off + 12].to_u64 |
                     (ico_data[off + 13].to_u64 << 8) |
                     (ico_data[off + 14].to_u64 << 16) |
                     (ico_data[off + 15].to_u64 << 24)

      return if size > max_size

      if image_offset >= 0 && (image_offset + size) <= ico_data.size && size >= 8
        img_slice = ico_data[image_offset, size.to_i]

        if png_signature?(img_slice)
          return from_slice?(img_slice)
        end
      end

      nil
    end

    private def decode_png
      return if @data.size < 8
      return unless png_signature?(@data)

      return if @data.size > MAX_PNG_SIZE

      decode_via_tempfile
    end

    private def decode_via_tempfile
      result = TempfileHelper.with_tempfile("prismatiq_png_", @data) do |png_path|
        begin
          img = CrImage.read(png_path)
        rescue ex : Exception
          debug_log("PNGExtractor: CrImage.read failed: #{ex.class} #{ex.message}")
          next false
        end
        return unless img

        w = img.bounds.width.to_i32
        h = img.bounds.height.to_i32
        return false if w > @config.max_image_width || h > @config.max_image_height

        rgba_image = begin
          CrImage::Pipeline.new(img).result
        rescue ex : Exception
          debug_log("PNGExtractor: Pipeline normalization failed: #{ex.class} #{ex.message}")
          nil
        end

        return unless rgba_image

        @width = w
        @height = h
        src = rgba_image.pix
        @pixels = Slice(UInt8).new(src.size)
        src.copy_to(@pixels)

        @valid = true
        true
      end

      return unless result
    end

    private def debug_log(*parts)
      @config.log_debug "PNGExtractor: #{parts.join(" ")}"
    end

    class PNGExtractError < Exception
    end

    private getter pixels : Slice(UInt8)
  end
end
