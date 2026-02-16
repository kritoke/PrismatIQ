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

describe PrismatIQ::PriorityQueue do
  it "maintains priority order" do
    pq = PrismatIQ::PriorityQueue(Int32).new { |a, b| b <=> a }
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
        pixels[idx] = 0   # r
        pixels[idx + 1] = 0 # g
        pixels[idx + 2] = 255 # b
        pixels[idx + 3] = 255 # a
      else
        pixels[idx] = 255 # r
        pixels[idx + 1] = 0 # g
        pixels[idx + 2] = 0 # b
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

    pal1 = PrismatIQ.get_palette_from_buffer(slice, width, height, 3, 1, 1)
    pal4 = PrismatIQ.get_palette_from_buffer(slice, width, height, 3, 1, 4)

    # Compare palettes (as hex arrays) for parity between 1 and multiple threads
    pal1_hex = pal1.map(&.to_hex)
    pal4_hex = pal4.map(&.to_hex)
    pal1_hex.should eq(pal4_hex)
  end
end
