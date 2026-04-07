module PrismatIQ
  module BinaryReader
    extend self

    PNG_SIGNATURE = Bytes[0x89_u8, 0x50_u8, 0x4E_u8, 0x47_u8]

    def png_signature?(slice : Slice(UInt8)) : Bool
      return false if slice.size < 4
      slice[0] == PNG_SIGNATURE[0] &&
        slice[1] == PNG_SIGNATURE[1] &&
        slice[2] == PNG_SIGNATURE[2] &&
        slice[3] == PNG_SIGNATURE[3]
    end

    def read_u16_le(slice : Slice(UInt8), idx : Int) : UInt16
      return 0_u16 if idx + 1 >= slice.size
      slice[idx].to_u16 | (slice[idx + 1].to_u16 << 8)
    end

    def read_u32_le(slice : Slice(UInt8), idx : Int) : UInt32
      return 0_u32 if idx + 3 >= slice.size
      slice[idx].to_u32 |
        (slice[idx + 1].to_u32 << 8) |
        (slice[idx + 2].to_u32 << 16) |
        (slice[idx + 3].to_u32 << 24)
    end

    def read_i32_le(slice : Slice(UInt8), idx : Int) : Int32
      read_u32_le(slice, idx).to_i32
    end

    def read_u16_le?(slice : Slice(UInt8), idx : Int) : UInt16?
      return if idx + 1 >= slice.size
      slice[idx].to_u16 | (slice[idx + 1].to_u16 << 8)
    end

    def read_u32_le?(slice : Slice(UInt8), idx : Int) : UInt32?
      return if idx + 3 >= slice.size
      slice[idx].to_u32 |
        (slice[idx + 1].to_u32 << 8) |
        (slice[idx + 2].to_u32 << 16) |
        (slice[idx + 3].to_u32 << 24)
    end

    def read_i32_le?(slice : Slice(UInt8), idx : Int) : Int32?
      v = read_u32_le?(slice, idx)
      v ? v.to_i32 : nil
    end
  end
end
