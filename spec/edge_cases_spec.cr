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
  describe "empty and minimal inputs" do
    it "handles empty pixel buffer" do
      empty = Slice(UInt8).new(0)
      result = PrismatIQ.get_palette_from_buffer(empty, 0, 0, color_count: 5)
      result.size.should eq(1)
      result[0].should be_a(PrismatIQ::RGB)
    end

    it "handles single pixel" do
      pixels = Slice.new(4) { |i| i == 3 ? 255.to_u8 : 0.to_u8 }
      result = PrismatIQ.get_palette_from_buffer(pixels, 1, 1, color_count: 3)
      result.size.should eq(1)
    end

    it "handles 1x1 transparent pixel" do
      pixels = Slice.new(4, 0.to_u8)
      result = PrismatIQ.get_palette_from_buffer(pixels, 1, 1, color_count: 5)
      result.size.should eq(1)
    end
  end

  describe "color count limits" do
    it "handles color_count of 1" do
      pixels = generate_checkerboard(10, 10)
      result = PrismatIQ.get_palette_from_buffer(pixels, 10, 10, color_count: 1)
      # color_count < 2 returns empty in MMCQ
      result.size.should eq(0)
    end

    it "handles large color_count" do
      pixels = generate_solid(255, 0, 0, 10, 10)
      result = PrismatIQ.get_palette_from_buffer(pixels, 10, 10, color_count: 100)
      result.size.should be > 0
    end
  end

  describe "quality parameter" do
    it "handles quality of 1 (every pixel)" do
      pixels = generate_checkerboard(10, 10)
      result = PrismatIQ.get_palette_from_buffer(pixels, 10, 10, quality: 1)
      result.size.should be > 0
    end

    it "handles high quality (skip pixels)" do
      pixels = generate_checkerboard(100, 100)
      result = PrismatIQ.get_palette_from_buffer(pixels, 100, 100, quality: 10)
      result.size.should be > 0
    end
  end

  describe "threading" do
    it "works with threads = 0 (auto)" do
      pixels = generate_checkerboard(20, 20)
      result = PrismatIQ.get_palette_from_buffer(pixels, 20, 20, threads: 0)
      result.size.should be > 0
    end

    it "works with negative threads (uses default)" do
      pixels = generate_solid(10, 20, 30, 10, 10)
      result = PrismatIQ.get_palette_from_buffer(pixels, 10, 10, threads: -1)
      result.size.should be > 0
    end
  end

  describe "Config" do
    it "works with custom debug setting" do
      pixels = generate_solid(255, 128, 64, 10, 10)
      config = PrismatIQ::Config.new(debug: true)
      result = PrismatIQ.get_palette_from_buffer(pixels, 10, 10, config: config)
      result.size.should be > 0
    end

    it "works with custom thread setting" do
      pixels = generate_solid(0, 255, 0, 10, 10)
      config = PrismatIQ::Config.new(threads: 2)
      result = PrismatIQ.get_palette_from_buffer(pixels, 10, 10, config: config)
      result.size.should be > 0
    end
  end

  describe "Result type with edge cases" do
    it "returns error for empty buffer" do
      empty = Slice(UInt8).new(0)
      result = PrismatIQ.get_palette_or_error(empty, 0, 0)
      result.ok?.should be_false
    end

    it "returns ok for valid input" do
      pixels = generate_solid(100, 100, 100, 10, 10)
      result = PrismatIQ.get_palette_or_error(pixels, 10, 10)
      result.ok?.should be_true
      result.value.size.should be > 0
    end
  end
end
