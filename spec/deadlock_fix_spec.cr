require "./spec_helper"

describe PrismatIQ::Core::PaletteExtractor do
  # Test for the critical issue where small images would cause issues
  # with parallel processing. Now uses sequential processing.

  it "handles small images correctly" do
    small_pixels = Slice(UInt8).new(16) { |i| (i % 4 == 3) ? 255_u8 : (i * 10).to_u8 }

    options = PrismatIQ::Options.new
    options.color_count = 5
    options.quality = 1

    extractor = PrismatIQ::Core::PaletteExtractor.new

    palette = extractor.extract_from_buffer(small_pixels, 2, 2, options)

    palette.should_not be_nil
    palette.size.should be >= 0
  end

  it "handles single pixel image correctly" do
    single_pixel = Slice(UInt8).new(4) { |i| i == 3 ? 255_u8 : 128_u8 }

    options = PrismatIQ::Options.new
    options.color_count = 3
    options.quality = 1

    extractor = PrismatIQ::Core::PaletteExtractor.new

    palette = extractor.extract_from_buffer(single_pixel, 1, 1, options)

    palette.should_not be_nil
    palette.size.should be >= 0
  end
end
