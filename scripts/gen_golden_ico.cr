#!/usr/bin/env crystal
require "crimage"
require "dir"

Dir.mkdir_p("spec/fixtures/ico") rescue nil

# Create a PNG 32x32
img = CrImage.rgba(32, 32)
32.times do |y|
  32.times do |x|
    img.set(x, y, CrImage::Color.rgba((x * 7) % 256, (y * 13) % 256, 128, 255))
  end
end
png_path = "spec/fixtures/ico/golden_png_32.png"
CrImage::PNG.write(png_path, img)
png_bytes = File.read(png_path)

# Write PNG-encoded ICO (one entry)
ico_png_path = "spec/fixtures/ico/png_icon_32x32.ico"
File.open(ico_png_path, "wb") do |f|
  f.write_bytes(0_u16, IO::ByteFormat::LittleEndian)
  f.write_bytes(1_u16, IO::ByteFormat::LittleEndian)
  f.write_bytes(1_u16, IO::ByteFormat::LittleEndian)

  f.write_byte(32_u8)
  f.write_byte(32_u8)
  f.write_byte(0_u8)
  f.write_byte(0_u8)
  f.write_bytes(0_u16, IO::ByteFormat::LittleEndian)
  f.write_bytes(0_u16, IO::ByteFormat::LittleEndian)
  f.write_bytes(png_bytes.size.to_u32, IO::ByteFormat::LittleEndian)
  f.write_bytes((6 + 16).to_u32, IO::ByteFormat::LittleEndian)

  # write PNG bytes one byte at a time to the file
  png_bytes.each_byte do |b|
    f.write_byte(b.to_u8)
  end
end

# Create BMP/DIB ICO using CrImage writer
bmp_ico_path = "spec/fixtures/ico/bmp_icon_16x16.ico"
img2 = CrImage.rgba(16, 16, CrImage::Color::BLUE)
CrImage::ICO.write(bmp_ico_path, img2)

puts "Wrote: #{ico_png_path} (#{File.size(ico_png_path)} bytes)"
puts "Wrote: #{bmp_ico_path} (#{File.size(bmp_ico_path)} bytes)"
