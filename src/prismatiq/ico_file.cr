require "./utils/binary_reader"
require "./bmp_parser"
require "./png_extractor"
require "./ico_entry"
require "./parsed_image"
require "./rgb"
require "./options"
require "./result"
require "./errors"
require "./config"

module PrismatIQ
  # ICOFile: Main class for parsing and processing ICO (icon) files
  #
  # This class encapsulates all ICO file processing, providing a clean interface
  # for reading ICO files, selecting the best icon entry, and extracting pixel data.
  # It supports both modern PNG-encoded entries and legacy BMP/DIB formats.
  #
  # ## Usage
  #
  # ```
  # ico = ICOFile.from_path("app.ico")
  # if ico.valid?
  #   pixels = ico.to_rgba
  #   width = ico.width
  #   height = ico.height
  # end
  # ```
  class ICOFile
    include BinaryReader

    MAX_ENTRY_SIZE = 50_000_000_i64
    getter width : Int32
    getter height : Int32
    getter entry_count : Int32
    getter entries : Array(ICOEntry)

    private getter data : Slice(UInt8)
    private getter config : Config

    def self.from_path(path : String, config : Config = Config.default) : ICOFile?
      # Validate path to prevent path traversal attacks
      validation = Utils::Validation.validate_file_path(path)
      return unless validation.ok?
      safe_path = validation.value

      file_size = File.size(safe_path) rescue 0_i64
      return if file_size > Constants::MAX_FILE_SIZE || file_size == 0
      bytes = File.read(safe_path).to_slice
      new(bytes, config)
    rescue ex : IO::Error | ArgumentError | IndexError
      config.log_debug "ICOFile.from_path: failed to read #{path}: #{ex.message}"
      nil
    end

    getter? valid : Bool

    def self.from_slice(data : Slice(UInt8), config : Config = Config.default) : ICOFile?
      new(data, config)
    rescue ex : ArgumentError | IndexError
      config.log_debug "ICOFile.from_slice: failed to parse: #{ex.message}"
      nil
    end

    def initialize(@data : Slice(UInt8), @config : Config = Config.default)
      @valid = false
      @width = 0
      @height = 0
      @entry_count = 0
      @entries = [] of ICOEntry

      parse
    end

    def valid?
      @valid
    end

    def to_rgba : Slice(UInt8)
      raise ICOError.new("Invalid ICO file") unless @valid
      extract_pixel_data
    end

    def to_image : ParsedImage
      raise ICOError.new("Invalid ICO file") unless @valid
      ParsedImage.new(@width, @height, extract_pixel_data)
    end

    def best_png_entry : Tuple(Int32, Int32, Slice(UInt8))?
      return if @data.size < 6

      header = parse_ico_header
      return unless header

      entry_base = 6
      i = 0
      while i < header[:count] && (entry_base + i * 16 + 16) <= @data.size
        png_data = find_png_entry(i, entry_base)
        return png_data if png_data
        i += 1
      end

      nil
    end

    def best_bmp_entry : Tuple(Int32, Int32, Slice(UInt8))?
      return if @data.size < 6

      header = parse_ico_header
      return unless header

      entry_base = 6
      best_entry = find_best_bmp(entry_base, header[:count])

      return unless best_entry
      {best_entry[0], best_entry[1], best_entry[2]}
    end

    private def find_png_entry(index : Int32, entry_base : Int32) : Tuple(Int32, Int32, Slice(UInt8))?
      off = entry_base + index * 16

      size = BinaryReader.read_u32_le(@data, off + 8).to_u64
      image_offset = BinaryReader.read_u32_le(@data, off + 12).to_u64

      return if size > MAX_ENTRY_SIZE
      return if image_offset + size > @data.size || size < 8

      img_slice = @data[image_offset, size.to_i]

      return unless valid_png_signature?(img_slice)

      width = @data[off].to_u32
      height = @data[off + 1].to_u32
      w = width.to_i32 == 0 ? 256 : width.to_i32
      h = height.to_i32 == 0 ? 256 : height.to_i32
      {w, h, img_slice}
    end

    private def valid_png_signature?(slice : Slice(UInt8)) : Bool
      png_signature?(slice)
    end

    private def find_best_bmp(entry_base : Int32, count : UInt16) : Tuple(Int32, Int32, Slice(UInt8))?
      best_area = 0_i32
      best_bitcount = 0_i32
      best_w : Int32 = 0
      best_h : Int32 = 0
      best_slice = nil

      i = 0
      while i < count && (entry_base + i * 16 + 16) <= @data.size
        result = find_bmp_entry(i, entry_base)
        if result
          w, h, bit_count, hdr = result
          area = w * h

          if area > best_area || (area == best_area && bit_count > best_bitcount)
            best_area = area
            best_bitcount = bit_count
            best_w = w
            best_h = h
            best_slice = hdr
          end
        end
        i += 1
      end

      return unless best_slice
      {best_w, best_h, best_slice}
    end

    private def find_bmp_entry(index : Int32, entry_base : Int32) : Tuple(Int32, Int32, Int32, Slice(UInt8))?
      off = entry_base + index * 16

      size = BinaryReader.read_u32_le(@data, off + 8).to_u64
      image_offset = BinaryReader.read_u32_le(@data, off + 12).to_u64

      return if image_offset + size > @data.size || size < 40

      hdr = @data[image_offset, size.to_i]
      header_size = read_u32_le(hdr, 0)
      return if header_size < 40 || size < header_size

      w = read_i32_le(hdr, 4)
      h_total = read_i32_le(hdr, 8)
      h = (h_total / 2).to_i32
      bit_count = read_u16_le(hdr, 14).to_i32

      return if w <= 0 || h <= 0 || ![1, 4, 8, 16, 24, 32].includes?(bit_count)
      return if w.to_i64 * h.to_i64 > 268_435_456_i64

      {w.to_i32, h, bit_count, hdr}
    end

    private def extract_pixel_data : Slice(UInt8)
      png_entry = best_png_entry
      return extract_from_png(png_entry) if png_entry

      bmp_entry = best_bmp_entry
      return extract_from_bmp(bmp_entry) if bmp_entry

      raise ICOError.new("No valid image data found in ICO file")
    end

    private def extract_from_png(png_entry : Tuple(Int32, Int32, Slice(UInt8))) : Slice(UInt8)
      w, h, png_data = png_entry

      return extract_from_bmp(best_bmp_entry) if png_data.size > MAX_ENTRY_SIZE

      ico_debug_log("ICOFile: using PNG entry #{w}x#{h}")

      extractor = PNGExtractor.from_slice?(png_data)
      return extract_from_bmp(best_bmp_entry) unless extractor && extractor.valid?

      @width = extractor.width
      @height = extractor.height
      extractor.to_rgba
    end

    private def extract_from_bmp(bmp_entry : Tuple(Int32, Int32, Slice(UInt8))?) : Slice(UInt8)
      return raise ICOError.new("No valid image data found in ICO file") unless bmp_entry

      w, h, bmp_data = bmp_entry
      ico_debug_log("ICOFile: using BMP entry #{w}x#{h}")

      parser = BMPParser.new(bmp_data, w, h, @config)
      return raise ICOError.new("BMP parsing failed") unless parser.valid?

      @width = parser.width
      @height = parser.height
      parser.to_rgba
    end

    private def parse
      header = parse_ico_header
      return unless header

      @entry_count = header[:count].to_i32

      entry_base = 6
      i = 0
      while i < header[:count] && (entry_base + i * 16 + 16) <= @data.size
        entry = ICOEntry.from_slice(@data, entry_base + i * 16)
        @entries << entry
        i += 1
      end

      @valid = @entries.size > 0
    end

    private def parse_ico_header : NamedTuple(reserved: UInt16, type: UInt16, count: UInt16)?
      return if @data.size < 6

      reserved = BinaryReader.read_u16_le(@data, 0)
      typ = BinaryReader.read_u16_le(@data, 2)
      count = BinaryReader.read_u16_le(@data, 4)

      return if reserved != 0 || (typ != 1 && typ != 2) || count <= 0

      {reserved: reserved, type: typ, count: count}
    end

    private def ico_debug_log(*parts)
      @config.log_debug parts.join(" ")
    end

    class ICOError < Exception
    end
  end

  # Extract palette from ICO file with explicit Error type (v2 API)
  def self.get_palette_from_ico_v2(path : String, options : Options = Options.default, config : Config = Config.default) : Result(Array(RGB), Error)
    ico = ICOFile.from_path(path, config)

    if !ico
      return Result(Array(RGB), Error).err(Error.file_not_found(path, "Failed to read ICO file"))
    end

    if !ico.valid?
      return Result(Array(RGB), Error).err(Error.invalid_image_path(path, "Invalid or corrupted ICO file"))
    end

    begin
      pixels = ico.to_rgba
      w = ico.width
      h = ico.height
      palette = get_palette_from_buffer(pixels, w, h, options)
      Result(Array(RGB), Error).ok(palette)
    rescue ex : Exception
      Result(Array(RGB), Error).err(Error.processing_failed(ex.message || "ICO processing failed"))
    end
  rescue ex : Exception
    Result(Array(RGB), Error).err(Error.processing_failed(ex.message || "Failed to extract palette from ICO"))
  end
end
