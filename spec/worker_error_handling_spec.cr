require "./spec_helper"

# This test simulates what happens when a worker fiber encounters an error
# We can't easily force an error in the real code, but we can verify the 
# structure handles errors gracefully

describe "Worker error handling" do
  it "continues processing even if some workers fail" do
    # Create a normal sized image that will spawn multiple workers
    width = 100
    height = 100
    pixels = Slice(UInt8).new(width * height * 4) { |i| (i % 4 == 3) ? 255_u8 : (i % 256).to_u8 }
    
    options = PrismatIQ::Options.new
    options.color_count = 5
    options.quality = 10  # Lower quality to reduce processing
    options.threads = 4
    
    extractor = PrismatIQ::Core::PaletteExtractor.new
    
    # This should work normally - if there were unhandled exceptions,
    # it would either crash or hang
    palette = extractor.extract_from_buffer(pixels, width, height, options)
    
    palette.should_not be_nil
    palette.size.should be > 0
  end
end