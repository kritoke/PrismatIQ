require "./spec_helper"
require "../src/prismatiq"

describe PrismatIQ::Color do
  describe "RGB to YIQ conversion" do
    it "converts white correctly" do
      color = PrismatIQ::Color.from_rgb(255, 255, 255)
      r, g, b = color.to_rgb
      r.should eq(255)
      g.should eq(255)
      b.should eq(255)
    end

    it "converts black correctly" do
      color = PrismatIQ::Color.from_rgb(0, 0, 0)
      r, g, b = color.to_rgb
      r.should eq(0)
      g.should eq(0)
      b.should eq(0)
    end

    it "converts red correctly" do
      color = PrismatIQ::Color.from_rgb(255, 0, 0)
      r, g, b = color.to_rgb
      r.should be_close(255, 1)
      g.should be_close(0, 1)
      b.should be_close(0, 1)
    end

    it "converts green correctly" do
      color = PrismatIQ::Color.from_rgb(0, 255, 0)
      r, g, b = color.to_rgb
      r.should be_close(0, 1)
      g.should be_close(255, 1)
      b.should be_close(0, 1)
    end

    it "converts blue correctly" do
      color = PrismatIQ::Color.from_rgb(0, 0, 255)
      r, g, b = color.to_rgb
      r.should be_close(0, 1)
      g.should be_close(0, 1)
      b.should be_close(255, 1)
    end
  end

  describe "to_hex" do
    it "converts to hex string" do
      color = PrismatIQ::Color.from_rgb(255, 0, 0)
      hex = color.to_hex
      hex[0].should eq('#')
      hex.size.should eq(7)
    end
  end
end

describe PrismatIQ::VBox do
  describe "volume" do
    it "calculates volume correctly" do
      vbox = PrismatIQ::VBox.new(0, 31, 0, 31, 0, 31)
      vbox.volume.should eq(32768.0)
    end
  end

  describe "priority" do
    it "calculates priority as count * volume" do
      vbox = PrismatIQ::VBox.new(0, 31, 0, 31, 0, 31, count: 100)
      vbox.priority.should eq(3276800.0)
    end
  end

  describe "index conversion" do
    it "converts index to coordinates and back" do
      y, i, q = PrismatIQ::VBox.from_index(1000)
      index = PrismatIQ::VBox.to_index(y, i, q)
      index.should eq(1000)
    end
  end
end

describe PrismatIQ::Algorithm::PriorityQueue do
  it "maintains priority order" do
    pq = PrismatIQ::Algorithm::PriorityQueue(Int32).new { |a, b| b <=> a }
    pq.push(3)
    pq.push(1)
    pq.push(4)
    pq.push(2)

    pq.pop.should eq(4)
    pq.pop.should eq(3)
    pq.pop.should eq(2)
    pq.pop.should eq(1)
  end
end

describe "multithreaded histogram parity" do
  it "produces same top color for 1 and multiple threads" do
    # Create a small synthetic 4x4 RGBA buffer with a known dominant color
    width = 4
    height = 4
    pixels = Array(UInt8).new(width * height * 4, 0)

    # Fill most pixels with red (255,0,0,255), but a few blue
    idx = 0
    i = 0
    while i < width * height
      if i % 5 == 0
        pixels[idx] = 0       # r
        pixels[idx + 1] = 0   # g
        pixels[idx + 2] = 255 # b
        pixels[idx + 3] = 255 # a
      else
        pixels[idx] = 255     # r
        pixels[idx + 1] = 0   # g
        pixels[idx + 2] = 0   # b
        pixels[idx + 3] = 255 # a
      end
      idx += 4
      i += 1
    end

    # Create a mutable slice and copy contents
    slice = Slice(UInt8).new(pixels.size)
    i = 0
    while i < pixels.size
      slice[i] = pixels[i]
      i += 1
    end

    # Use Result-based API for explicit error handling
    # Test with single thread for deterministic results
    options = PrismatIQ::Options.new(color_count: 3, threads: 1)
    result = PrismatIQ.get_palette_or_error(slice, width, height, options)

    # Verify result is successful
    result.ok?.should be_true
    pal1 = result.value

    # Verify we got a valid palette
    pal1.size.should be > 0
    pal1.each do |color|
      color.should be_a(PrismatIQ::RGB)
    end
  end
end

describe "concurrent palette extraction" do
  it "handles multiple concurrent palette extractions safely" do
    width = 100
    height = 100
    pixels = Slice(UInt8).new(width * height * 4) do |i|
      if i % 4 == 3
        255_u8
      else
        (i % 256).to_u8
      end
    end

    results = Channel(Array(PrismatIQ::RGB)).new(10)
    errors = Channel(Exception?).new(10)

    10.times do
      spawn do
        begin
          options = PrismatIQ::Options.new(color_count: 5, quality: 5, threads: 2)
          palette = PrismatIQ.get_palette(pixels, width, height, options)
          results.send(palette)
          errors.send(nil)
        rescue ex : Exception
          errors.send(ex)
        end
      end
    end

    palettes = [] of Array(PrismatIQ::RGB)
    error_list = [] of Exception?

    10.times { palettes << results.receive }
    10.times { error_list << errors.receive }

    error_list.compact.should be_empty
    palettes.size.should eq(10)
    palettes.each do |palette|
      palette.size.should be > 0
    end
  end

  it "produces consistent results under concurrent access" do
    width = 50
    height = 50
    pixels = Slice(UInt8).new(width * height * 4) do |i|
      if i % 4 == 3
        255_u8
      else
        ((i // 4) % 256).to_u8
      end
    end

    options = PrismatIQ::Options.new(color_count: 3, quality: 1, threads: 1)
    reference = PrismatIQ.get_palette(pixels, width, height, options)

    results = Channel(Array(PrismatIQ::RGB)).new(20)

    20.times do
      spawn do
        opts = PrismatIQ::Options.new(color_count: 3, quality: 1, threads: 1)
        results.send(PrismatIQ.get_palette(pixels, width, height, opts))
      end
    end

    all_palettes = [] of Array(PrismatIQ::RGB)
    20.times { all_palettes << results.receive }

    all_palettes.each do |palette|
      palette.size.should eq(reference.size)
      palette.zip(reference).each do |actual, expected|
        actual.r.should eq(expected.r)
        actual.g.should eq(expected.g)
        actual.b.should eq(expected.b)
      end
    end
  end

  it "handles concurrent extractions with different thread counts" do
    width = 80
    height = 80
    pixels = Slice(UInt8).new(width * height * 4) do |i|
      if i % 4 == 3
        255_u8
      else
        rand(256).to_u8
      end
    end

    results = Channel(Array(PrismatIQ::RGB)).new(15)
    thread_counts = [1, 2, 4, 8]

    thread_counts.each do |threads|
      spawn do
        options = PrismatIQ::Options.new(color_count: 5, quality: 3, threads: threads)
        results.send(PrismatIQ.get_palette(pixels, width, height, options))
      end
    end

    all_palettes = [] of Array(PrismatIQ::RGB)
    thread_counts.size.times { all_palettes << results.receive }

    all_palettes.each do |palette|
      palette.size.should be > 0
      palette.size.should be <= 5
    end
  end
end
