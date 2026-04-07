require "./utils/binary_reader"

module PrismatIQ
  # BMPParser: Parser for legacy BMP/DIB format parsing
  #
  # This class handles parsing of Windows BMP/DIB (Device Independent Bitmap) format
  # data embedded within ICO files or as standalone BMP files.
  #
  # ## Supported Formats
  #
  # - **1bpp** (monochrome) with 2-color palette
  # - **4bpp** (16-color) with 16-color palette
  # - **8bpp** (256-color) with 256-color palette
  # - **16bpp** with optional bitfield masks
  # - **24bpp** (true color, BGR order)
  # - **32bpp** (true color with alpha, BGRA order)
  #
  # ## Features
  #
  # - Supports both bottom-up (standard) and top-down BMP formats
  # - Handles AND mask for transparency in legacy icons
  # - Bitfield compression support (BI_BITFIELDS)
  # - 4-byte row alignment handling
  # - Converts all formats to RGBA for consistent processing
  #
  # ## Usage
  #
  # ```
  # parser = BMPParser.new(bmp_slice)
  # if parser.valid?
  #   image = parser.to_image
  #   width = image.width
  #   height = image.height
  #   pixels = image.pixels
  # end
  # ```
  #
  # ## BMP File Format Reference
  #
  # A BMP/DIB image in an ICO file consists of:
  # - **BITMAPINFOHEADER**: 40 bytes (or larger for extended headers)
  # - **Color Palette**: 4 bytes per entry (B, G, R, Reserved) - present for <=8bpp
  # - **XOR Mask**: Pixel data (size varies by dimensions and bit depth)
  # - **AND Mask**: 1bpp transparency mask (height equals image height for ICO)
  #
  class BMPParser
    include BinaryReader

    class BMPParseError < Exception
    end

    getter? valid : Bool
    getter width : Int32
    getter height : Int32
    getter bit_count : Int32
    getter compression : UInt32
    getter colors_used : UInt32

    private getter config : Config

    private def read_u16_le(idx : Int) : UInt16
      BinaryReader.read_u16_le(@data, idx)
    end

    private def read_u32_le(idx : Int) : UInt32
      BinaryReader.read_u32_le(@data, idx)
    end

    private def read_i32_le(idx : Int) : Int32
      BinaryReader.read_i32_le(@data, idx)
    end

    def initialize(@data : Slice(UInt8), @config : Config = Config.default)
      @valid = false
      @width = 0
      @height = 0
      @bit_count = 0
      @compression = 0_u32
      @colors_used = 0_u32

      parse_header
    end

    def initialize(@data : Slice(UInt8), width : Int32, height : Int32, @config : Config = Config.default)
      @valid = false
      @width = width
      @height = height
      @bit_count = 0
      @compression = 0_u32
      @colors_used = 0_u32

      parse_header_fields if @data.size >= 40
    end

    # Parse header fields except dimensions (used when dimensions are pre-set)
    private def parse_header_fields
      header_size = read_u32_le(0)
      return if header_size < 40

      @bit_count = read_u16_le(14).to_i32
      @compression = read_u32_le(16)

      # Colors used field is at offset 32
      if @data.size >= 36
        @colors_used = read_u32_le(32)
      end

      validate_dimensions
    end

    private def validate_dimensions
      return unless @width > 0 && @height > 0
      return unless [1, 4, 8, 16, 24, 32].includes?(@bit_count)
      return unless @compression == 0 || @compression == 3
      pixel_count = @width.to_i64 * @height.to_i64
      return if pixel_count > MAX_PIXEL_COUNT
      @valid = true
    end

    MAX_PIXEL_COUNT = 268_435_456_i64 # 16384 * 16384

    private def safe_pixel_buffer_size : Int32?
      total = @width.to_i64 * @height.to_i64 * 4
      return nil if total > Int32::MAX.to_i64 || total > MAX_PIXEL_COUNT * 4
      total.to_i32
    end

    # Returns the pixel data as RGBA bytes
    #
    # Returns a Slice(UInt8) of size width * height * 4 containing
    # RGBA pixel data in row-major order (top-to-bottom).
    #
    # Raises BMPParseError if the image is not valid.
    #
    # ```
    # pixels = parser.to_rgba
    # # pixels[0..3] = first pixel R, G, B, A
    # ```
    def to_rgba : Slice(UInt8)
      raise BMPParseError.new("Invalid BMP data") unless @valid

      buf_size = safe_pixel_buffer_size
      raise BMPParseError.new("BMP dimensions too large") unless buf_size
      pixels = Slice(UInt8).new(buf_size)
      decode_pixels(pixels)
      pixels
    end

    # Returns a ParsedImage struct containing width, height, and RGBA pixels
    #
    # This is a convenience method that combines dimension retrieval and
    # pixel decoding.
    #
    # ```
    # image = parser.to_image
    # puts "Size: #{image.width}x#{image.height}"
    # ```
    def to_image : ParsedImage
      raise BMPParseError.new("Invalid BMP data") unless @valid

      buf_size = safe_pixel_buffer_size
      raise BMPParseError.new("BMP dimensions too large") unless buf_size
      pixels = Slice(UInt8).new(buf_size)
      decode_pixels(pixels)
      ParsedImage.new(@width, @height, pixels)
    end

    # Creates a BMPParser from raw bytes, returning nil on failure
    #
    # This is a convenience factory method that catches exceptions.
    #
    # ```
    # parser = BMPParser.from_slice?(bytes)
    # if parser && parser.valid?
    #   # process
    # end
    # ```
    def self.from_slice?(data : Slice(UInt8), config : Config = Config.default) : BMPParser?
      parser = new(data, config)
      parser.valid? ? parser : nil
    rescue ex : Exception
      config.log_debug "BMPParser.from_slice?: #{ex.class}: #{ex.message}"
      nil
    end

    # Parse the BMP header (BITMAPINFOHEADER)
    private def parse_header
      return if @data.size < 40

      header_size = read_u32_le(0)
      return if header_size < 40

      @width = read_i32_le(4).abs
      height_signed = read_i32_le(8)
      @height = height_signed.abs
      @bit_count = read_u16_le(14).to_i32
      @compression = read_u32_le(16)

      # Colors used field is at offset 32
      if @data.size >= 36
        @colors_used = read_u32_le(32)
      end

      validate_dimensions
    end

    # Decode all pixels into the provided RGBA buffer
    private def decode_pixels(pixels : Slice(UInt8))
      header_size = read_u32_le(0)
      top_down = read_i32_le(8) < 0

      # Handle ICO-style doubled height (includes AND mask)
      actual_height = @height
      if @data.size >= 12
        raw_height = read_i32_le(8)
        if raw_height.abs > @height * 2
          actual_height = (raw_height.abs / 2).to_i32
        end
      end

      # Get color palette if present
      palette = extract_palette

      # Calculate row sizes
      xor_row_size = ((@width * @bit_count + 31) // 32) * 4
      and_row_size = ((@width + 31) // 32) * 4

      # Calculate offsets
      pixel_data_offset = header_size + (palette.size * 4)
      and_mask_offset = pixel_data_offset + (xor_row_size * actual_height)

      # Determine bitfield masks if using compression
      red_mask = 0_u32
      green_mask = 0_u32
      blue_mask = 0_u32
      alpha_mask = 0_u32

      if @compression == 3 && @data.size >= 52
        red_mask = read_u32_le(40)
        green_mask = read_u32_le(44)
        blue_mask = read_u32_le(48)
        alpha_mask = read_u32_le(52) if @data.size >= 56
      elsif @bit_count == 16 && @compression == 0
        red_mask = 0x0000F800_u32
        green_mask = 0x000007E0_u32
        blue_mask = 0x0000001F_u32
        alpha_mask = 0_u32
      end

      # Fast path for common uncompressed formats
      if (@bit_count == 32 || @bit_count == 24) && @compression == 0
        decode_rgb_direct(pixels, pixel_data_offset, xor_row_size, top_down)
        return
      end

      # Generic path for paletted and unusual formats
      decode_generic(pixels, pixel_data_offset, xor_row_size, and_mask_offset,
        and_row_size, actual_height, top_down, palette,
        red_mask, green_mask, blue_mask, alpha_mask)
    end

    # Extract the color palette from BMP data
    private def extract_palette : Array(Tuple(UInt8, UInt8, UInt8, UInt8))
      return [] of Tuple(UInt8, UInt8, UInt8, UInt8) if @bit_count > 8

      num_colors = @colors_used > 0 ? @colors_used.to_i32 : (1 << @bit_count)
      palette_offset = read_u32_le(0)

      palette = Array(Tuple(UInt8, UInt8, UInt8, UInt8)).new

      num_colors.times do |i|
        offset = palette_offset + i * 4
        break if offset + 3 >= @data.size

        palette << {@data[offset + 2], @data[offset + 1], @data[offset], @data[offset + 3]}
      end

      # Fill missing palette entries with black
      while palette.size < (1 << @bit_count)
        palette << ({0_u8, 0_u8, 0_u8, 255_u8})
      end

      palette
    end

    # Fast path for 32bpp and 24bpp uncompressed data
    private def decode_rgb_direct(pixels : Slice(UInt8), pixel_offset : UInt32,
                                  row_size : Int32, top_down : Bool)
      bytes_per_pixel = @bit_count // 8

      y = 0
      while y < @height
        src_row = top_down ? y : (@height - 1 - y)
        row_offset = pixel_offset.to_i64 + src_row.to_i64 * row_size.to_i64
        next if row_offset >= @data.size.to_i64 || row_offset < 0
        row_start = row_offset.to_i32

        x = 0
        while x < @width
          src_idx = row_start + x * bytes_per_pixel

          r, g, b, a = read_rgb_rgba(src_idx)

          dest_idx = (y * @width + x) * 4
          pixels[dest_idx] = r
          pixels[dest_idx + 1] = g
          pixels[dest_idx + 2] = b
          pixels[dest_idx + 3] = a

          x += 1
        end
        y += 1
      end
    end

    # Read RGB or RGBA pixel data at given index
    private def read_rgb_rgba(src_idx : Int32) : Tuple(UInt8, UInt8, UInt8, UInt8)
      if @bit_count == 32
        if src_idx + 3 < @data.size
          return {@data[src_idx + 2], @data[src_idx + 1], @data[src_idx], @data[src_idx + 3]}
        end
        return {0_u8, 0_u8, 0_u8, 0_u8}
      end

      # 24bpp
      if src_idx + 2 < @data.size
        return {@data[src_idx + 2], @data[src_idx + 1], @data[src_idx], 255_u8}
      end
      {0_u8, 0_u8, 0_u8, 255_u8}
    end

    # Decode a single pixel in the generic path
    private def decode_generic_pixel(x : Int32, y : Int32, row_start : Int32, src_row : Int32,
                                     palette : Array(Tuple(UInt8, UInt8, UInt8, UInt8)),
                                     red_mask : UInt32, green_mask : UInt32,
                                     blue_mask : UInt32, alpha_mask : UInt32)
      case @bit_count
      when 1, 4, 8
        pixel_byte = @data[row_start + (x * @bit_count // 8)]
        if @bit_count == 8
          idx = pixel_byte
        elsif @bit_count == 4
          idx = (pixel_byte >> (4 - (x % 2) * 4)) & 0x0F
        else
          idx = (pixel_byte >> (7 - (x % 8))) & 1
        end
        if idx < palette.size
          return palette[idx]
        end
      when 16
        offset = row_start + x * 2
        if offset + 1 < @data.size
          pixel = @data[offset].to_u32 | (@data[offset + 1].to_u32 << 8)
          r_shift = mask_to_shift_bits(red_mask)
          g_shift = mask_to_shift_bits(green_mask)
          b_shift = mask_to_shift_bits(blue_mask)
          a_shift = mask_to_shift_bits(alpha_mask)

          r_val = ((pixel & red_mask) >> r_shift[0]) & 0xFF if r_shift[0] >= 0
          g_val = ((pixel & green_mask) >> g_shift[0]) & 0xFF if g_shift[0] >= 0
          b_val = ((pixel & blue_mask) >> b_shift[0]) & 0xFF if b_shift[0] >= 0
          a_val = ((pixel & alpha_mask) >> a_shift[0]) & 0xFF if a_shift[0] >= 0

          r = (r_val || 0_u32).to_u8
          g = (g_val || 0_u32).to_u8
          b = (b_val || 0_u32).to_u8
          a = (a_val || 255_u32).to_u8
          return {r, g, b, a}
        end
      end
      {0_u8, 0_u8, 0_u8, 255_u8}
    end

    # Generic decoding path for paletted and unusual formats
    private def decode_generic(pixels : Slice(UInt8), pixel_offset : UInt32,
                               xor_row_size : Int32, and_offset : UInt32,
                               and_row_size : Int32, actual_height : Int32,
                               top_down : Bool, palette : Array(Tuple(UInt8, UInt8, UInt8, UInt8)),
                               red_mask : UInt32, green_mask : UInt32,
                               blue_mask : UInt32, alpha_mask : UInt32)
      y = 0
      while y < @height
        src_row = top_down ? y : (actual_height - 1 - y)
        row_offset = pixel_offset.to_i64 + src_row.to_i64 * xor_row_size.to_i64
        next if row_offset >= @data.size.to_i64 || row_offset < 0
        row_start = row_offset.to_i32

        x = 0
        while x < @width
          px_r, px_g, px_b, px_a = decode_generic_pixel(x, y, row_start, src_row, palette, red_mask, green_mask, blue_mask, alpha_mask)

          # Apply AND mask transparency
          mask_row_offset = and_offset.to_i64 + src_row.to_i64 * and_row_size.to_i64
          next unless mask_row_offset < @data.size.to_i64
          mask_row_start = mask_row_offset.to_i32
          mask_byte_idx = mask_row_start + (x // 8)
          if mask_byte_idx >= 0 && mask_byte_idx < @data.size
            mask_val = @data[mask_byte_idx]
            bit = 7 - (x % 8)
            px_a = 0_u8 if ((mask_val >> bit) & 1) == 1
          end

          dest_idx = (y * @width + x) * 4
          pixels[dest_idx] = px_r
          pixels[dest_idx + 1] = px_g
          pixels[dest_idx + 2] = px_b
          pixels[dest_idx + 3] = px_a

          x += 1
        end
        y += 1
      end
    end

    private def mask_to_shift_bits(mask : UInt32) : Tuple(Int32, Int32)
      return {-1, 0} if mask == 0_u32

      shift = 0
      m = mask
      while (m & 1_u32) == 0_u32
        m >>= 1
        shift += 1
      end

      bits = 0
      while (m & 1_u32) == 1_u32
        m >>= 1
        bits += 1
      end

      {shift, bits}
    end
  end
end
