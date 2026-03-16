module PrismatIQ
  module BinaryReader
    extend self

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
