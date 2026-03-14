require "./spec_helper"
require "../src/prismatiq"

def generate_checkerboard(width, height)
  pixels = Array(UInt8).new(width * height * 4)
  y = 0
  while y < height
    x = 0
    while x < width
      if (x + y) % 2 == 0
        pixels << 255.to_u8
        pixels << 0.to_u8
        pixels << 0.to_u8
        pixels << 255.to_u8
      else
        pixels << 0.to_u8
        pixels << 255.to_u8
        pixels << 0.to_u8
        pixels << 255.to_u8
      end
      x += 1
    end
    y += 1
  end
  Slice.new(pixels.size) { |idx| pixels[idx] }
end

def generate_solid(r, g, b, width, height)
  pixels = Array(UInt8).new(width * height * 4)
  height.times do
    width.times do
      pixels << r.to_u8
      pixels << g.to_u8
      pixels << b.to_u8
      pixels << 255.to_u8
    end
  end
  Slice.new(pixels.size) { |idx| pixels[idx] }
end

describe "PrismatIQ Edge Cases" do
  describe "empty and minimal inputs (Result-based API)" do
    it "handles empty pixel buffer using get_palette_or_error" do
      empty = Slice(UInt8).new(0)
      options = PrismatIQ::Options.new(color_count: 5)
      result = PrismatIQ.get_palette_or_error(empty, 0, 0, options)
      # Empty buffer returns fallback palette with black
      result.ok?.should be_true
      result.value.size.should eq(1)
    end

    it "handles single pixel using get_palette_or_error" do
      pixels = Slice.new(4) { |i| i == 3 ? 255.to_u8 : 0.to_u8 }
      options = PrismatIQ::Options.new(color_count: 3)
      result = PrismatIQ.get_palette_or_error(pixels, 1, 1, options)
      result.ok?.should be_true
      result.value.size.should eq(1)
    end

    it "handles 1x1 transparent pixel using get_palette_or_error" do
      pixels = Slice.new(4, 0.to_u8)
      options = PrismatIQ::Options.new(color_count: 5)
      result = PrismatIQ.get_palette_or_error(pixels, 1, 1, options)
      # Transparent pixel may return error or empty palette
      if result.ok?
        result.value.size.should eq(1)
      else
        result.error.should contain("No valid pixels")
      end
    end
  end

  describe "color count limits (Result-based API)" do
    it "handles color_count of 1" do
      pixels = generate_checkerboard(10, 10)
      options = PrismatIQ::Options.new(color_count: 1)
      result = PrismatIQ.get_palette_or_error(pixels, 10, 10, options)
      result.ok?.should be_true
      # color_count = 1 now correctly returns 1 color
      result.value.size.should eq(1)
    end

    it "handles large color_count" do
      pixels = generate_solid(255, 0, 0, 10, 10)
      options = PrismatIQ::Options.new(color_count: 100)
      result = PrismatIQ.get_palette_or_error(pixels, 10, 10, options)
      result.ok?.should be_true
      result.value.size.should be > 0
    end
  end

  describe "quality parameter (Result-based API)" do
    it "handles quality of 1 (every pixel)" do
      pixels = generate_checkerboard(10, 10)
      options = PrismatIQ::Options.new(quality: 1)
      result = PrismatIQ.get_palette_or_error(pixels, 10, 10, options)
      result.ok?.should be_true
      result.value.size.should be > 0
    end

    it "handles high quality (skip pixels)" do
      pixels = generate_checkerboard(100, 100)
      options = PrismatIQ::Options.new(quality: 10)
      result = PrismatIQ.get_palette_or_error(pixels, 100, 100, options)
      result.ok?.should be_true
      result.value.size.should be > 0
    end
  end

  describe "threading (Result-based API)" do
    it "works with threads = 0 (auto)" do
      pixels = generate_checkerboard(20, 20)
      options = PrismatIQ::Options.new(threads: 0)
      result = PrismatIQ.get_palette_or_error(pixels, 20, 20, options)
      result.ok?.should be_true
      result.value.size.should be > 0
    end

    it "works with negative threads (uses default)" do
      pixels = generate_solid(10, 20, 30, 10, 10)
      options = PrismatIQ::Options.new(threads: -1)
      result = PrismatIQ.get_palette_or_error(pixels, 10, 10, options)
      # Negative threads may cause validation error - handle both cases
      if result.ok?
        result.value.size.should be > 0
      else
        result.error.should contain("threads")
      end
    end
  end

  describe "Config (Result-based API)" do
    it "works with custom debug setting" do
      pixels = generate_solid(255, 128, 64, 10, 10)
      options = PrismatIQ::Options.new
      config = PrismatIQ::Config.new(debug: false)
      result = PrismatIQ.get_palette_or_error(pixels, 10, 10, options, config)
      result.ok?.should be_true
      result.value.size.should be > 0
    end

    it "works with custom thread setting" do
      pixels = generate_solid(0, 255, 0, 10, 10)
      options = PrismatIQ::Options.new
      config = PrismatIQ::Config.new(threads: 1)
      result = PrismatIQ.get_palette_or_error(pixels, 10, 10, options, config)
      result.ok?.should be_true
      result.value.size.should be > 0
    end
  end

  describe "Result type with edge cases" do
    it "returns palette for empty buffer using get_palette_or_error" do
      empty = Slice(UInt8).new(0)
      options = PrismatIQ::Options.new(color_count: 5)
      result = PrismatIQ.get_palette_or_error(empty, 0, 0, options)
      # Empty buffer returns fallback palette with black
      result.ok?.should be_true
      result.value.size.should eq(1)
    end

    it "returns ok for valid input using get_palette_or_error" do
      pixels = generate_solid(100, 100, 100, 10, 10)
      options = PrismatIQ::Options.new(color_count: 3)
      result = PrismatIQ.get_palette_or_error(pixels, 10, 10, options)
      result.ok?.should be_true
      result.value.size.should be > 0
    end

    it "uses get_palette_v2 for extraction" do
      pixels = generate_solid(50, 100, 150, 10, 10)
      options = PrismatIQ::Options.new
      result = PrismatIQ.get_palette_v2(pixels, 10, 10, options)
      result.ok?.should be_true
      result.value.should be_a(Array(PrismatIQ::RGB))
    end

    it "demonstrates value_or for default handling" do
      empty = Slice(UInt8).new(0)
      options = PrismatIQ::Options.new(color_count: 5)
      result = PrismatIQ.get_palette_or_error(empty, 0, 0, options)
      default = [PrismatIQ::RGB.new(0, 0, 0)]
      palette = result.value_or(default)
      palette.should eq(default)
    end

    it "demonstrates map for result transformation" do
      pixels = generate_solid(200, 50, 100, 10, 10)
      options = PrismatIQ::Options.new(color_count: 3)
      result = PrismatIQ.get_palette_or_error(pixels, 10, 10, options)
      # Map transforms the successful result
      hex_result = result.map { |colors| colors.map(&.to_hex) }
      hex_result.ok?.should be_true
      hex_result.value.size.should be > 0
    end

    it "demonstrates map_error for error transformation" do
      empty = Slice(UInt8).new(0)
      options = PrismatIQ::Options.new(color_count: 5)
      result = PrismatIQ.get_palette_or_error(empty, 0, 0, options)
      # Map error transforms the error case
      if result.err?
        mapped = result.map_error { |e| "Custom error: #{e}" }
        mapped.error.should contain("Custom error:")
      end
    end
  end
end
