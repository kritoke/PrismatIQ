require "spec"
require "../src/prismatiq"

# Test helpers for loading binary RGBA fixtures.
# Expected fixture format:
#  - first 4 bytes: width (UInt32 little-endian)
#  - next 4 bytes: height (UInt32 little-endian)
#  - remaining bytes: raw RGBA bytes (width * height * 4)
def load_rgba_fixture(path : String) : Tuple(Slice(UInt8), Int32, Int32)
  bytes = File.read_bytes(path)
  raise "fixture too small: #{path}" if bytes.size < 8

  # try little-endian first, then big-endian; accept whichever matches body size
  le_width = bytes[0].to_u32 | (bytes[1].to_u32 << 8) | (bytes[2].to_u32 << 16) | (bytes[3].to_u32 << 24)
  le_height = bytes[4].to_u32 | (bytes[5].to_u32 << 8) | (bytes[6].to_u32 << 16) | (bytes[7].to_u32 << 24)

  be_width = (bytes[0].to_u32 << 24) | (bytes[1].to_u32 << 16) | (bytes[2].to_u32 << 8) | bytes[3].to_u32
  be_height = (bytes[4].to_u32 << 24) | (bytes[5].to_u32 << 16) | (bytes[6].to_u32 << 8) | bytes[7].to_u32

  le_expected = le_width.to_i64 * le_height.to_i64 * 4
  be_expected = be_width.to_i64 * be_height.to_i64 * 4
  body_size = bytes.size - 8

  if body_size == le_expected
    width = le_width.to_i32
    height = le_height.to_i32
  elsif body_size == be_expected
    width = be_width.to_i32
    height = be_height.to_i32
  else
    raise "fixture body size does not match header (path=#{path} body=#{body_size} le_expected=#{le_expected} be_expected=#{be_expected})"
  end

  body = bytes[8, (width.to_i64 * height.to_i64 * 4).to_i]
  slice = Slice(UInt8).new(body.size)
  i = 0
  while i < body.size
    slice[i] = body[i]
    i += 1
  end

  { slice, width, height }
end
