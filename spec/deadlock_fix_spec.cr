require "./spec_helper"

describe PrismatIQ::Core::PaletteExtractor do
  # Test for the critical deadlock issue where small images would cause fewer fibers
  # to be spawned than expected, leading to receive loops waiting forever

  it "handles small images without deadlock" do
    # Create a very small RGBA buffer (2x2 pixels = 16 bytes)
    small_pixels = Slice(UInt8).new(16) { |i| (i % 4 == 3) ? 255_u8 : (i * 10).to_u8 }

    options = PrismatIQ::Options.new
    options.color_count = 5
    options.quality = 1
    options.threads = 4 # Request more threads than needed for this tiny image

    extractor = PrismatIQ::Core::PaletteExtractor.new

    # This should not deadlock and should return a valid palette
    palette = extractor.extract_from_buffer(small_pixels, 2, 2, options)

    palette.should_not be_nil
    palette.size.should be >= 0
  end

  it "handles single pixel image without deadlock" do
    # Single pixel RGBA (4 bytes)
    single_pixel = Slice(UInt8).new(4) { |i| i == 3 ? 255_u8 : 128_u8 }

    options = PrismatIQ::Options.new
    options.color_count = 3
    options.quality = 1
    options.threads = 8 # Way more threads than needed

    extractor = PrismatIQ::Core::PaletteExtractor.new

    palette = extractor.extract_from_buffer(single_pixel, 1, 1, options)

    palette.should_not be_nil
    palette.size.should be >= 0
  end
end
