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
  # # Extract PNG from ICO entry bytes
  # extractor = PNGExtractor.new(png_bytes)
  # if extractor.valid?
  #   image = extractor.to_image
  #   puts "Decoded PNG: #{image.width}x#{image.height}"
  #   pixels = image.pixels # RGBA pixel data
  # end
  # ```
  #
  # ## Comparison with BMPParser
  #
  # BMPParser handles legacy BMP/DIB format while PNGExtractor handles
  # modern PNG-compressed images. Both return a consistent `ParsedImage`
  # structure with width, height, and RGBA pixels.
  class PNGExtractor
    # Result of PNG extraction containing RGBA pixel data and dimensions
    struct ParsedImage
      getter width : Int32
      getter height : Int32
      getter pixels : Slice(UInt8)

      def initialize(@width, @height, @pixels)
      end
    end

    # Error types for PNG extraction
    class PNGExtractError < Exception
    end

    # Maximum allowed PNG size in bytes (50 MB default)
    MAX_PNG_SIZE = 50_000_000_i64

    # Whether the PNG data was successfully decoded
    getter? valid : Bool

    # Width of the decoded image in pixels
    getter width : Int32

    # Height of the decoded image in pixels
    getter height : Int32

    # Creates a new PNGExtractor from a byte slice containing PNG data
    #
    # The slice should contain valid PNG data as extracted from an ICO entry.
    #
    # ```
    # extractor = PNGExtractor.new(png_data)
    # ```
    def initialize(@data : Slice(UInt8))
      @valid = false
      @width = 0
      @height = 0
      @pixels = Slice(UInt8).new(0)

      decode_png
    end

    # Returns whether the PNG data was successfully decoded
    def valid?
      @valid
    end

    # Returns the pixel data as RGBA bytes
    #
    # Returns a Slice(UInt8) of size width * height * 4 containing
    # RGBA pixel data in row-major order (top-to-bottom).
    #
    # Raises PNGExtractError if the image is not valid.
    #
    # ```
    # pixels = extractor.to_rgba
    # # pixels[0..3] = first pixel R, G, B, A
    # ```
    def to_rgba : Slice(UInt8)
      raise PNGExtractError.new("Invalid PNG data") unless @valid
      @pixels
    end

    # Returns a ParsedImage struct containing width, height, and RGBA pixels
    #
    # This is a convenience method that returns all extracted data in one call.
    #
    # ```
    # image = extractor.to_image
    # puts "Size: #{image.width}x#{image.height}"
    # ```
    def to_image : ParsedImage
      raise PNGExtractError.new("Invalid PNG data") unless @valid
      ParsedImage.new(@width, @height, @pixels)
    end

    # Creates a PNGExtractor from raw bytes, returning nil on failure
    #
    # This is a convenience factory method that catches exceptions.
    #
    # ```
    # extractor = PNGExtractor.from_slice?(png_bytes)
    # if extractor && extractor.valid?
    #   # process
    # end
    # ```
    def self.from_slice?(data : Slice(UInt8)) : PNGExtractor?
      begin
        extractor = new(data)
        extractor.valid? ? extractor : nil
      rescue
        nil
      end
    end

    # Extracts PNG data from an ICO file and returns a PNGExtractor
    #
    # This method searches for PNG-encoded entries in the ICO file and
    # returns a PNGExtractor for the first PNG found.
    #
    # ```
    # extractor = PNGExtractor.extract_from_ico(ico_bytes)
    # if extractor && extractor.valid?
    #   image = extractor.to_image
    # end
    # ```
    def self.extract_from_ico(ico_data : Slice(UInt8), max_size : Int64 = MAX_PNG_SIZE) : PNGExtractor?
      return nil if ico_data.size < 6

      # Read ICONDIR header
      reserved = ico_data[0].to_u16 | (ico_data[1].to_u16 << 8)
      typ = ico_data[2].to_u16 | (ico_data[3].to_u16 << 8)
      count = ico_data[4].to_u16 | (ico_data[5].to_u16 << 8)

      return nil if reserved != 0 || (typ != 1 && typ != 2) || count <= 0

      # Search for PNG entries
      entry_base = 6
      i = 0
      while i < count && (entry_base + 16) <= ico_data.size
        off = entry_base + i * 16
        width = ico_data[off].to_u32
        height = ico_data[off + 1].to_u32

        size = ico_data[off + 8].to_u64 |
               (ico_data[off + 9].to_u64 << 8) |
               (ico_data[off + 10].to_u64 << 16) |
               (ico_data[off + 11].to_u64 << 24)

        image_offset = ico_data[off + 12].to_u64 |
                       (ico_data[off + 13].to_u64 << 8) |
                       (ico_data[off + 14].to_u64 << 16) |
                       (ico_data[off + 15].to_u64 << 24)

        # Check size limit
        if size > max_size
          i += 1
          next
        end

        if image_offset >= 0 && (image_offset + size) <= ico_data.size && size >= 8
          img_slice = ico_data[image_offset, size.to_i]

          # Check PNG signature: 0x89 0x50 0x4E 0x47
          if img_slice[0] == 0x89_u8 && img_slice[1] == 0x50_u8 &&
             img_slice[2] == 0x4E_u8 && img_slice[3] == 0x47_u8
            return from_slice?(img_slice)
          end
        end

        i += 1
      end

      nil
    end

    private def decode_png
      # Validate PNG signature
      return if @data.size < 8
      return if @data[0] != 0x89_u8 || @data[1] != 0x50_u8 ||
                @data[2] != 0x4E_u8 || @data[3] != 0x47_u8

      # Size validation to prevent DoS
      return if @data.size > MAX_PNG_SIZE

      # Try file-based decoding (most reliable for CrImage)
      decode_via_tempfile
    end

    private def decode_via_tempfile
      # Create temp file for PNG decoding using with_tempfile for automatic cleanup
      result = TempfileHelper.with_tempfile("prismatiq_png_", @data) do |png_path|
        img = CrImage.read(png_path)
        return unless img

        # Use Pipeline to normalize to RGBA
        rgba_image = nil
        begin
          rgba_image = CrImage::Pipeline.new(img).result
        rescue ex : Exception
          debug_log("PNGExtractor: Pipeline normalization failed: #{ex.class} #{ex.message}")
        end

        return unless rgba_image

        @width = rgba_image.bounds.width.to_i32
        @height = rgba_image.bounds.height.to_i32
        src = rgba_image.pix
        @pixels = Slice(UInt8).new(src.size)

        # Copy pixel data
        src.size.times do |i|
          @pixels[i] = src[i]
        end

        @valid = true
        true
      end

      # with_tempfile returns nil if file creation failed
      return unless result
    end

    private def debug_log(*parts)
      if ENV.has_key?("PRISMATIQ_DEBUG")
        STDERR.puts "PNGExtractor: #{parts.join(" ")}"
      end
    end
  end

  # ICO (Icon) file format support for PrismatIQ
  #
  # This module provides functionality to extract color palettes from Windows ICO files.
  # It supports both modern PNG-encoded icons and legacy BMP/DIB formats.
  #
  # ## Supported Formats
  #
  # - **PNG-encoded ICO entries** (preferred, most common in modern applications)
  # - **BMP/DIB formats**: 1bpp, 4bpp, 8bpp (paletted), 24bpp, 32bpp (RGB/RGBA)
  # - **Bitfield compression** for 16bpp and 32bpp variants
  # - **AND mask transparency** for classic BMP icons
  #
  # ## Limitations
  #
  # - Currently selects the largest/highest quality icon from multi-icon files
  # - Maximum embedded image size: 50MB (configurable via code modification)
  # - Compressed BMP formats (RLE) are not supported
  # - ICO files must be valid and not corrupted
  #
  # ## Usage Examples
  #
  # ```
  # # Basic usage - extract palette from a favicon
  # palette = PrismatIQ.get_palette_from_ico("favicon.ico", color_count: 5)
  # palette.each { |color| puts color.to_hex }
  # ```
  #
  # ```
  # # With custom parameters
  # palette = PrismatIQ.get_palette_from_ico(
  #   "app.ico",
  #   color_count: 8, # Extract 8 dominant colors
  #   quality: 5,     # Higher quality (lower = more accurate, slower)
  #   threads: 4      # Use 4 threads for processing
  # )
  # ```
  #
  # ```
  # # Handle potential errors
  # begin
  #   palette = PrismatIQ.get_palette_from_ico("icon.ico")
  #   if palette.size == 1 && palette[0].r == 0 && palette[0].g == 0 && palette[0].b == 0
  #     puts "Warning: Could not extract meaningful palette"
  #   else
  #     puts "Extracted #{palette.size} colors"
  #   end
  # rescue ex : Exception
  #   puts "Error processing ICO: #{ex.message}"
  # end
  # ```
  #
  # ## Technical Details
  #
  # ICO files can contain multiple icon images at different sizes and formats. This implementation:
  #
  # 1. **Scans for PNG-encoded entries** (preferred for quality and modern compatibility)
  # 2. **Falls back to BMP/DIB parsing** if no PNG found
  # 3. **Selects the largest/highest bit-depth entry** for best color representation
  # 4. **Handles transparency** via alpha channel (32bpp) or AND mask (classic BMP)
  # 5. **Uses secure tempfile handling** for PNG entries to ensure safe processing
  #
  # ## File Format Structure
  #
  # An ICO file consists of:
  # - **ICONDIR header**: 6 bytes (reserved, type, count)
  # - **ICONDIRENTRY array**: 16 bytes per entry (width, height, colors, reserved, planes, bpp, size, offset)
  # - **Image data**: PNG or BMP/DIB format
  #
  # ## Performance Considerations
  #
  # - PNG entries are processed via secure tempfile for stability
  # - BMP parsing is done in-memory for efficiency
  # - Multi-threaded histogram building available via `threads` parameter
  # - Quality parameter controls sampling density (lower = more accurate but slower)
  #
  # ## Debugging
  #
  # Set `PRISMATIQ_DEBUG=true` environment variable to see detailed processing information:
  #
  # ```bash
  # PRISMATIQ_DEBUG=true crystal run your_script.cr
  # ```

  # Represents a single icon entry (ICONDIRENTRY) within an ICO file.
  #
  # Each ICO file can contain multiple icon images at different sizes and color depths.
  # This struct captures the metadata for a single icon entry as defined in the
  # Windows ICO file format specification.
  #
  # ### ICO File Format
  #
  # ```
  # Offset | Size | Description
  # -------|------|-------------
  # 0      | 1    | Width (0 = 256)
  # 1      | 1    | Height (0 = 256)
  # 2      | 1    | Color count (0 = 256+)
  # 3      | 1    | Reserved (must be 0)
  # 4      | 2    | Color planes
  # 6      | 2    | Bits per pixel
  # 8      | 4    | Size of image data in bytes
  # 12     | 4    | Offset to image data from start of file
  # ```
  #
  # ### Usage
  #
  # ```
  # entry = ICOEntry.from_bytes(slice, offset: 6)
  # puts "Icon size: #{entry.width}x#{entry.height}"
  # puts "Bits per pixel: #{entry.bit_count}"
  # puts "Image data at offset: #{entry.image_offset}"
  # ```
  struct ICOEntry
    # Width of the icon in pixels (0 means 256)
    getter width : UInt8

    # Height of the icon in pixels (0 means 256)
    getter height : UInt8

    # Number of colors in the color palette (0 means 256 or no palette)
    getter color_count : UInt8

    # Reserved, always 0
    getter reserved : UInt8

    # Number of color planes (typically 1)
    getter color_planes : UInt16

    # Bits per pixel (1, 4, 8, 24, or 32)
    getter bit_count : UInt16

    # Size of the image data in bytes
    getter size_in_bytes : UInt32

    # Offset from the beginning of the ICO file to the image data
    getter image_offset : UInt32

    # Returns the actual width, where 0 is interpreted as 256
    def actual_width : Int32
      width == 0 ? 256 : width.to_i32
    end

    # Returns the actual height, where 0 is interpreted as 256
    def actual_height : Int32
      height == 0 ? 256 : height.to_i32
    end

    # Returns the approximate pixel area of this icon entry
    def area : Int32
      actual_width * actual_height
    end

    # Returns whether this entry contains PNG-encoded image data
    def png? : Bool
      size_in_bytes >= 8 &&
        image_offset + size_in_bytes <= MaxUInt32 &&
        true # Actual PNG check done at read time with slice access
    end

    # Creates an ICOEntry from raw bytes at the specified offset.
    #
    # The entry is read from a 16-byte ICONDIRENTRY structure.
    #
    # ```
    # entry = ICOEntry.from_slice(bytes, offset: 6)
    # ```
    def self.from_slice(slice : Slice(UInt8), offset : Int) : ICOEntry
      raise IndexError.new("ICOEntry: slice too small at offset #{offset}") if offset + 16 > slice.size

      w = slice[offset]
      h = slice[offset + 1]
      colors = slice[offset + 2]
      res = slice[offset + 3]
      planes = slice[offset + 4].to_u16 | (slice[offset + 5].to_u16 << 8)
      bpp = slice[offset + 6].to_u16 | (slice[offset + 7].to_u16 << 8)
      size = slice[offset + 8].to_u32 |
             (slice[offset + 9].to_u32 << 8) |
             (slice[offset + 10].to_u32 << 16) |
             (slice[offset + 11].to_u32 << 24)
      img_off = slice[offset + 12].to_u32 |
                (slice[offset + 13].to_u32 << 8) |
                (slice[offset + 14].to_u32 << 16) |
                (slice[offset + 15].to_u32 << 24)

      new(w, h, colors, res, planes, bpp, size, img_off)
    end

    def initialize(
      @width : UInt8,
      @height : UInt8,
      @color_count : UInt8,
      @reserved : UInt8,
      @color_planes : UInt16,
      @bit_count : UInt16,
      @size_in_bytes : UInt32,
      @image_offset : UInt32,
    )
    end

    # Returns a string representation of this entry for debugging
    def to_s : String
      "ICOEntry(#{actual_width}x#{actual_height} @#{image_offset}, #{bit_count}bpp, #{size_in_bytes}bytes)"
    end
  end

  # ICOFile: Main class for parsing and processing ICO (icon) files
  #
  # This class encapsulates all ICO file processing, providing a clean interface
  # for reading ICO files, selecting the best icon entry, and extracting pixel data.
  # It supports both modern PNG-encoded entries and legacy BMP/DIB formats.
  #
  # ## Features
  #
  # - Parses ICO file headers and directory entries
  # - Selects the best quality entry (PNG preferred, then largest BMP)
  # - Delegates PNG extraction to PNGExtractor
  # - Delegates BMP parsing to BMPParser
  # - Returns RGBA pixel data for palette extraction
  #
  # ## Usage
  #
  # ```
  # ico = ICOFile.from_path("app.ico")
  # if ico.valid?
  #   pixels = ico.to_rgba
  #   width = ico.width
  #   height = ico.height
  #   # Extract palette from pixels
  # end
  # ```
  #
  # ```
  # # From raw bytes
  # ico = ICOFile.from_slice(ico_bytes)
  # if ico.valid?
  #   image = ico.to_image
  # end
  # ```
  class ICOFile
    # Result of ICOFile parsing containing RGBA pixel data and dimensions
    struct ParsedImage
      getter width : Int32
      getter height : Int32
      getter pixels : Slice(UInt8)

      def initialize(@width, @height, @pixels)
      end
    end

    # Error types for ICO file processing
    class ICOError < Exception
    end

    # Maximum allowed embedded image size (50 MB)
    MAX_ENTRY_SIZE = 50_000_000_i64

    # Whether the ICO file was successfully parsed
    getter? valid : Bool

    # Width of the selected icon in pixels
    getter width : Int32

    # Height of the selected icon in pixels
    getter height : Int32

    # Number of icon entries in the ICO file
    getter entry_count : Int32

    # All entries found in the ICO file
    getter entries : Array(ICOEntry)

    # Raw bytes of the ICO file
    private getter data : Slice(UInt8)

    # Creates an ICOFile from a file path
    #
    # ```
    # ico = ICOFile.from_path("favicon.ico")
    # ```
    def self.from_path(path : String) : ICOFile?
      begin
        bytes = File.read(path).to_slice
        new(bytes)
      rescue ex : Exception
        debug_log("ICOFile.from_path: failed to read #{path}: #{ex.message}")
        nil
      end
    end

    # Creates an ICOFile from raw bytes
    #
    # ```
    # ico = ICOFile.from_slice(ico_bytes)
    # ```
    def self.from_slice(data : Slice(UInt8)) : ICOFile?
      return nil if data.nil?
      new(data)
    end

    # Creates a new ICOFile from a byte slice
    def initialize(@data : Slice(UInt8))
      @valid = false
      @width = 0
      @height = 0
      @entry_count = 0
      @entries = [] of ICOEntry

      parse
    end

    # Returns whether the ICO file was successfully parsed
    def valid?
      @valid
    end

    # Returns the pixel data as RGBA bytes
    #
    # Returns a Slice(UInt8) of size width * height * 4 containing
    # RGBA pixel data in row-major order (top-to-bottom).
    #
    # Raises ICOError if the file is not valid.
    #
    # ```
    # pixels = ico.to_rgba
    # # pixels[0..3] = first pixel R, G, B, A
    # ```
    def to_rgba : Slice(UInt8)
      raise ICOError.new("Invalid ICO file") unless @valid
      extract_pixel_data
    end

    # Returns a ParsedImage struct containing width, height, and RGBA pixels
    #
    # This is a convenience method that returns all extracted data in one call.
    #
    # ```
    # image = ico.to_image
    # puts "Size: #{image.width}x#{image.height}"
    # ```
    def to_image : ParsedImage
      raise ICOError.new("Invalid ICO file") unless @valid
      ParsedImage.new(@width, @height, extract_pixel_data)
    end

    # Finds and returns the best PNG entry in the ICO file
    #
    # Returns a tuple of {width, height, PNG data slice} or nil if no PNG found.
    #
    # ```
    # if png = ico.best_png_entry
    #   w, h, data = png
    # end
    # ```
    def best_png_entry : Tuple(Int32, Int32, Slice(UInt8))?
      return nil if @data.size < 6

      # Read ICONDIR header
      reserved = @data[0].to_u16 | (@data[1].to_u16 << 8)
      typ = @data[2].to_u16 | (@data[3].to_u16 << 8)
      count = @data[4].to_u16 | (@data[5].to_u16 << 8)

      return nil if reserved != 0 || (typ != 1 && typ != 2) || count <= 0

      entry_base = 6
      i = 0
      while i < count && (entry_base + 16) <= @data.size
        png_data = find_png_at_entry(i, entry_base)
        return png_data if png_data
        i += 1
      end

      nil
    end

    # Check a single ICO entry for PNG data
    private def find_png_at_entry(index : Int32, entry_base : Int32) : Tuple(Int32, Int32, Slice(UInt8))?
      off = entry_base + index * 16

      size = @data[off + 8].to_u64 |
             (@data[off + 9].to_u64 << 8) |
             (@data[off + 10].to_u64 << 16) |
             (@data[off + 11].to_u64 << 24)

      image_offset = @data[off + 12].to_u64 |
                     (@data[off + 13].to_u64 << 8) |
                     (@data[off + 14].to_u64 << 16) |
                     (@data[off + 15].to_u64 << 24)

      # Check size limit
      return nil if size > MAX_ENTRY_SIZE
      return nil if image_offset + size > @data.size || size < 8

      img_slice = @data[image_offset, size.to_i]

      # Check PNG signature: 0x89 0x50 0x4E 0x47
      return nil unless valid_png_signature?(img_slice)

      width = @data[off].to_u32
      height = @data[off + 1].to_u32
      w = width.to_i32 == 0 ? 256 : width.to_i32
      h = height.to_i32 == 0 ? 256 : height.to_i32
      {w, h, img_slice}
    end

    # Check if a slice starts with valid PNG signature
    private def valid_png_signature?(slice : Slice(UInt8)) : Bool
      return false if slice.size < 8
      slice[0] == 0x89_u8 && slice[1] == 0x50_u8 &&
        slice[2] == 0x4E_u8 && slice[3] == 0x47_u8
    end

    # Finds and returns the best BMP entry in the ICO file
    #
    # Prefers the largest area entry, with bit count as tiebreaker.
    #
    # Returns a tuple of {width, height, BMP data slice} or nil if no BMP found.
    #
    # ```
    # if bmp = ico.best_bmp_entry
    #   w, h, data = bmp
    # end
    # ```
    def best_bmp_entry : Tuple(Int32, Int32, Slice(UInt8))?
      return nil if @data.size < 6

      # Read ICONDIR header
      reserved = @data[0].to_u16 | (@data[1].to_u16 << 8)
      typ = @data[2].to_u16 | (@data[3].to_u16 << 8)
      count = @data[4].to_u16 | (@data[5].to_u16 << 8)

      return nil if reserved != 0 || (typ != 1 && typ != 2) || count <= 0

      entry_base = 6
      best_area = 0_i32
      best_bitcount = 0_i32
      best_w : Int32 = 0
      best_h : Int32 = 0
      best_slice = nil

      i = 0
      while i < count && (entry_base + 16) <= @data.size
        result = find_bmp_at_entry(i, entry_base)
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

      return nil unless best_slice
      {best_w, best_h, best_slice}
    end

    # Check a single ICO entry for BMP data, returns dimensions and data if valid
    private def find_bmp_at_entry(index : Int32, entry_base : Int32) : Tuple(Int32, Int32, Int32, Slice(UInt8))?
      off = entry_base + index * 16

      size = @data[off + 8].to_u64 |
             (@data[off + 9].to_u64 << 8) |
             (@data[off + 10].to_u64 << 16) |
             (@data[off + 11].to_u64 << 24)

      image_offset = @data[off + 12].to_u64 |
                     (@data[off + 13].to_u64 << 8) |
                     (@data[off + 14].to_u64 << 16) |
                     (@data[off + 15].to_u64 << 24)

      return nil if image_offset + size > @data.size || size < 40

      hdr = @data[image_offset, size.to_i]
      header_size = read_u32_le(hdr, 0)
      return nil if header_size < 40 || size < header_size

      w = read_i32_le(hdr, 4)
      h_total = read_i32_le(hdr, 8)
      # ICO BMP stores height as doubled (image + AND mask)
      h = (h_total / 2).to_i32
      bit_count = read_u16_le(hdr, 14).to_i32

      # Basic sanity checks
      return nil if w <= 0 || h <= 0 || bit_count < 24

      {w.to_i32, h, bit_count, hdr}
    end

    # Extracts RGBA pixel data from the best available entry
    #
    # Prefers PNG entries for quality, falls back to BMP parsing.
    private def extract_pixel_data : Slice(UInt8)
      # Try PNG first (preferred for quality)
      png_entry = best_png_entry
      return extract_from_png(png_entry) if png_entry

      # Fall back to BMP parsing
      bmp_entry = best_bmp_entry
      return extract_from_bmp(bmp_entry) if bmp_entry

      raise ICOError.new("No valid image data found in ICO file")
    end

    # Extract RGBA data from a PNG entry
    private def extract_from_png(png_entry : Tuple(Int32, Int32, Slice(UInt8))) : Slice(UInt8)
      w, h, png_data = png_entry

      # Size guard
      return extract_from_bmp(best_bmp_entry) if png_data.size > MAX_ENTRY_SIZE

      ico_debug_log("ICOFile: using PNG entry #{w}x#{h}")

      extractor = PNGExtractor.from_slice?(png_data)
      return extract_from_bmp(best_bmp_entry) unless extractor && extractor.valid?

      @width = extractor.width
      @height = extractor.height
      extractor.to_rgba
    end

    # Extract RGBA data from a BMP entry
    private def extract_from_bmp(bmp_entry : Tuple(Int32, Int32, Slice(UInt8))?) : Slice(UInt8)
      return raise ICOError.new("No valid image data found in ICO file") unless bmp_entry

      w, h, bmp_data = bmp_entry
      ico_debug_log("ICOFile: using BMP entry #{w}x#{h}")

      parser = BMPParser.new(bmp_data, w, h)
      return raise ICOError.new("BMP parsing failed") unless parser.valid?

      @width = parser.width
      @height = parser.height
      parser.to_rgba
    end

    private def parse
      # Minimum size for ICO header
      return if @data.size < 6

      # Read ICONDIR header
      reserved = @data[0].to_u16 | (@data[1].to_u16 << 8)
      typ = @data[2].to_u16 | (@data[3].to_u16 << 8)
      count = @data[4].to_u16 | (@data[5].to_u16 << 8)

      return if reserved != 0 || (typ != 1 && typ != 2) || count <= 0

      @entry_count = count.to_i32

      # Parse all entries
      entry_base = 6
      i = 0
      while i < count && (entry_base + 16) <= @data.size
        entry = ICOEntry.from_slice(@data, entry_base + i * 16)
        @entries << entry
        i += 1
      end

      @valid = @entries.size > 0
    end

    private def read_u16_le(slice : Slice(UInt8), idx : Int) : Int32
      if idx + 1 >= slice.size
        raise IndexError.new("read_u16_le: index out of bounds")
      end
      (slice[idx].to_u32 | (slice[idx + 1].to_u32 << 8)).to_i32
    end

    private def read_u32_le(slice : Slice(UInt8), idx : Int) : UInt64
      if idx + 3 >= slice.size
        raise IndexError.new("read_u32_le: index out of bounds")
      end
      (slice[idx].to_u64 | (slice[idx + 1].to_u64 << 8) |
        slice[idx + 2].to_u64 << 16 | (slice[idx + 3].to_u64 << 24)).to_u64
    end

    private def read_i32_le(slice : Slice(UInt8), idx : Int) : Int64
      if idx + 3 >= slice.size
        raise IndexError.new("read_i32_le: index out of bounds")
      end
      (slice[idx].to_u64 | (slice[idx + 1].to_u64 << 8) |
        slice[idx + 2].to_u64 << 16 | (slice[idx + 3].to_u64 << 24)).to_i64
    end

    private def self.read_u16_le(slice : Slice(UInt8), idx : Int) : Int32
      if idx + 1 >= slice.size
        raise IndexError.new("read_u16_le: index out of bounds")
      end
      (slice[idx].to_u32 | (slice[idx + 1].to_u32 << 8)).to_i32
    end

    private def self.read_u32_le(slice : Slice(UInt8), idx : Int) : UInt64
      if idx + 3 >= slice.size
        raise IndexError.new("read_u32_le: index out of bounds")
      end
      (slice[idx].to_u64 | (slice[idx + 1].to_u64 << 8) |
        slice[idx + 2].to_u64 << 16 | (slice[idx + 3].to_u64 << 24)).to_u64
    end

    private def self.read_i32_le(slice : Slice(UInt8), idx : Int) : Int64
      if idx + 3 >= slice.size
        raise IndexError.new("read_i32_le: index out of bounds")
      end
      (slice[idx].to_u64 | (slice[idx + 1].to_u64 << 8) |
        slice[idx + 2].to_u64 << 16 | (slice[idx + 3].to_u64 << 24)).to_i64
    end

    private def self.debug_log(*parts)
      if ENV.has_key?("PRISMATIQ_DEBUG")
        STDERR.puts parts.join(" ")
      end
    end

    # Debug helper for ICOFile instance methods
    private def ico_debug_log(*parts)
      if ENV.has_key?("PRISMATIQ_DEBUG")
        STDERR.puts parts.join(" ")
      end
    end
  end

  # Maximum value for UInt32, used for bounds checking
  private MaxUInt32 = 0xFFFFFFFF_u32

  # Read a 16-bit unsigned little-endian value from a byte slice
  private def self.read_u16_le(slice : Slice(UInt8), idx : Int) : Int32
    if idx + 1 >= slice.size
      raise IndexError.new("read_u16_le: index out of bounds")
    end
    (slice[idx].to_u32 | (slice[idx + 1].to_u32 << 8)).to_i32
  end

  # Return a 32-bit unsigned little-endian value as UInt64 to avoid
  # accidental 32-bit signed overflows when working with file offsets/sizes.
  private def self.read_u32_le(slice : Slice(UInt8), idx : Int) : UInt64
    if idx + 3 >= slice.size
      raise IndexError.new("read_u32_le: index out of bounds")
    end
    (slice[idx].to_u64 | (slice[idx + 1].to_u64 << 8) | (slice[idx + 2].to_u64 << 16) | (slice[idx + 3].to_u64 << 24)).to_u64
  end

  # Return a 32-bit signed little-endian value as Int64 for safer arithmetic
  # when calculating dimensions and signed header fields.
  private def self.read_i32_le(slice : Slice(UInt8), idx : Int) : Int64
    if idx + 3 >= slice.size
      raise IndexError.new("read_i32_le: index out of bounds")
    end
    (slice[idx].to_u64 | (slice[idx + 1].to_u64 << 8) | (slice[idx + 2].to_u64 << 16) | (slice[idx + 3].to_u64 << 24)).to_i64
  end

  # Extract a color palette from an ICO (icon) file, returning a Result type for explicit error handling
  #
  # This is the robust version of get_palette_from_ico that returns explicit errors.
  #
  # ## Parameters
  #
  # - **path**: Path to the ICO file
  # - **options**: Options struct containing color_count, quality, and threads settings
  #
  # ## Returns
  #
  # A `Result(Array(RGB), String)` where:
  # - Success contains the palette array
  # - Error contains a descriptive error message
  #
  # ## Examples
  #
  # ```
  # result = PrismatIQ.get_palette_from_ico_or_error("favicon.ico")
  # if result.ok?
  #   colors = result.value
  #   colors.each { |c| puts c.to_hex }
  # else
  #   puts "Error: #{result.error}"
  # end
  # ```
  def self.get_palette_from_ico_or_error(path : String, options : Options = Options.default) : Result(Array(RGB), String)
    begin
      palette = get_palette_from_ico(path, options)
      # Check if it's the error sentinel
      if palette.size == 1 && palette[0].r == 0 && palette[0].g == 0 && palette[0].b == 0
        Result(Array(RGB), String).err("Failed to extract palette from ICO file: #{path}")
      else
        Result(Array(RGB), String).ok(palette)
      end
    rescue ex : Exception
      Result(Array(RGB), String).err("Exception processing ICO file #{path}: #{ex.message}")
    end
  end

  # Backward-compatible overload with keyword arguments
  @[Deprecated("Use `get_palette_from_ico_or_error(path, Options.new(color_count: N, quality: Q, threads: T))` instead")]
  def self.get_palette_from_ico_or_error(path : String, color_count : Int32, quality : Int32 = 10, threads : Int32 = 0) : Result(Array(RGB), String)
    get_palette_from_ico_or_error(path, Options.new(color_count, quality, threads))
  end

  # Extract a color palette from an ICO (icon) file
  #
  # This is the main public API for extracting dominant colors from ICO files.
  # It automatically handles both modern PNG-encoded and legacy BMP-encoded icons.
  #
  # ## Parameters
  #
  # - **path**: Path to the ICO file
  # - **options**: Options struct containing color_count, quality, and threads settings
  #
  # ## Returns
  #
  # An `Array(RGB)` of dominant colors, sorted by prominence.
  # Returns `[RGB.new(0, 0, 0)]` for invalid/corrupted files
  # (use get_palette_from_ico_or_error for explicit error handling).
  #
  # ## Examples
  #
  # ```
  # # Extract 5 dominant colors from a favicon
  # colors = PrismatIQ.get_palette_from_ico("favicon.ico")
  # # Note: Check for error sentinel [RGB.new(0,0,0)] or use get_palette_from_ico_or_error
  # colors.each { |c| puts c.to_hex }
  # ```
  #
  # ```
  # # Extract 10 colors with high quality
  # colors = PrismatIQ.get_palette_from_ico("app.ico", Options.new(color_count: 10, quality: 5))
  # ```
  #
  # ## Algorithm
  #
  # 1. Reads ICO file header to validate format
  # 2. Scans entries for PNG-encoded images (preferred)
  # 3. Falls back to BMP/DIB parsing if no PNG found
  # 4. Selects largest/highest quality entry
  # 5. Extracts pixel data with transparency handling
  # 6. Runs MMCQ quantization to find dominant colors
  #
  # ## Error Handling
  #
  # - Returns `[RGB.new(0, 0, 0)]` for invalid/corrupted files
  # - Falls back to generic image decoding for non-ICO files
  # - Debug output available via `PRISMATIQ_DEBUG=true` env var
  # - For explicit error handling, use get_palette_from_ico_or_error
  def self.get_palette_from_ico(path : String, options : Options = Options.default) : Array(RGB)
    # Try to create ICOFile from path
    ico = ICOFile.from_path(path)

    # Process valid ICO file
    if ico && ico.valid?
      return process_ico_palette(ico, options)
    end

    # Fallback: try generic image decoding with CrImage
    img = CrImage.read(path)
    get_palette(img, options)
  rescue ex : Exception
    debug_log("ICO: unexpected error processing #{path}: #{ex.message}")
    [RGB.new(0, 0, 0)]
  end

  # Backward-compatible overload with keyword arguments
  @[Deprecated("Use `get_palette_from_ico(path, Options.new(color_count: N, quality: Q, threads: T))` instead")]
  def self.get_palette_from_ico(path : String, color_count : Int32, quality : Int32 = 10, threads : Int32 = 0) : Array(RGB)
    get_palette_from_ico(path, Options.new(color_count, quality, threads))
  end

  # Process palette extraction from a valid ICOFile
  private def self.process_ico_palette(ico : ICOFile, options : Options) : Array(RGB)
    pixels = ico.to_rgba
    w = ico.width
    h = ico.height

    debug_log("ICO: successfully parsed ICO file, dimensions: #{w}x#{h}")
    get_palette_from_buffer(pixels, w, h, options)
  rescue ex : Exception
    debug_log("ICO: ICOFile extraction failed: #{ex.message}")
    [RGB.new(0, 0, 0)]
  end

  # Debug helper: gated by PRISMATIQ_DEBUG env var
  private def self.debug_log(*parts)
    if ENV.has_key?("PRISMATIQ_DEBUG")
      STDERR.puts parts.join(" ")
    end
  end
end
