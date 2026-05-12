module PrismatIQ
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
  struct ICOEntry
    getter width : UInt8
    getter height : UInt8
    getter color_count : UInt8
    getter reserved : UInt8
    getter color_planes : UInt16
    getter bit_count : UInt16
    getter size_in_bytes : UInt32
    getter image_offset : UInt32

    def actual_width : Int32
      width == 0 ? 256 : width.to_i32
    end

    def actual_height : Int32
      height == 0 ? 256 : height.to_i32
    end

    def area : Int32
      actual_width * actual_height
    end

    def self.from_slice(slice : Slice(UInt8), offset : Int) : ICOEntry
      raise IndexError.new("ICOEntry: slice too small at offset #{offset}") if offset + 16 > slice.size

      w = slice[offset]
      h = slice[offset + 1]
      colors = slice[offset + 2]
      res = slice[offset + 3]
      planes = BinaryReader.read_u16_le(slice, offset + 4)
      bpp = BinaryReader.read_u16_le(slice, offset + 6)
      size = BinaryReader.read_u32_le(slice, offset + 8)
      img_off = BinaryReader.read_u32_le(slice, offset + 12)

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

    def to_s : String
      "ICOEntry(#{actual_width}x#{actual_height} @#{image_offset}, #{bit_count}bpp, #{size_in_bytes}bytes)"
    end
  end
end
