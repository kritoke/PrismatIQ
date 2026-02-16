require "./spec_helper"
require "../src/prismatiq"

describe "Palette stats and ColorThief compatibility" do
  it "returns entries with counts and percentages that sum to ~1 and hex format" do
    width = 4
    height = 4
    pixels = Array(UInt8).new(width * height * 4, 0)

    # Fill most pixels with red, some blue (deterministic)
    idx = 0
    i = 0
    while i < width * height
      if i % 5 == 0
        pixels[idx] = 0
        pixels[idx + 1] = 0
        pixels[idx + 2] = 255
        pixels[idx + 3] = 255
      else
        pixels[idx] = 255
        pixels[idx + 1] = 0
        pixels[idx + 2] = 0
        pixels[idx + 3] = 255
      end
      idx += 4
      i += 1
    end

    # copy to Slice(UInt8)
    slice = Slice(UInt8).new(pixels.size)
    i = 0
    while i < pixels.size
      slice[i] = pixels[i]
      i += 1
    end

    entries, total = PrismatIQ.get_palette_with_stats_from_buffer(slice, width, height, 3, 1, 1)

    total.should eq(width * height)

    # entries should be non-empty and each entry should have valid hex, count and percent
    entries.size.should be > 0
    sum_percent = 0.0
    sum_counts = 0
    entries.each do |e|
      e.count.should be > 0
      e.percent.should be_close(e.count.to_f64 / total.to_f64, 0.0001)
      sum_percent += e.percent
      sum_counts += e.count

      hex = e.rgb.to_hex
      hex[0].should eq('#')
      hex.size.should eq(7)
    end

    # The percentages should sum to approximately 1.0 (allow small rounding error)
    sum_percent.should be_close(1.0, 0.0001)

    # And counts should sum to total
    sum_counts.should eq(total)
  end

  it "compatibility wrapper returns same hex list as entries" do
    width = 4
    height = 4
    pixels = Array(UInt8).new(width * height * 4, 0)

    idx = 0
    i = 0
    while i < width * height
      if i % 3 == 0
        pixels[idx] = 0
        pixels[idx + 1] = 255
        pixels[idx + 2] = 0
        pixels[idx + 3] = 255
      else
        pixels[idx] = 255
        pixels[idx + 1] = 255
        pixels[idx + 2] = 0
        pixels[idx + 3] = 255
      end
      idx += 4
      i += 1
    end

    slice = Slice(UInt8).new(pixels.size)
    i = 0
    while i < pixels.size
      slice[i] = pixels[i]
      i += 1
    end

    entries, total = PrismatIQ.get_palette_with_stats_from_buffer(slice, width, height, 4, 1, 1)
    ct = PrismatIQ.get_palette_color_thief_from_buffer(slice, width, height, 4, 1, 1)

    expected = entries.map { |e| e.rgb.to_hex }
    ct.should eq(expected)
  end

  it "color thief wrapper is deterministic across thread counts" do
    width = 8
    height = 8
    pixels = Array(UInt8).new(width * height * 4, 0)

    idx = 0
    i = 0
    while i < width * height
      if i % 7 == 0
        pixels[idx] = 123
        pixels[idx + 1] = 50
        pixels[idx + 2] = 200
        pixels[idx + 3] = 255
      else
        pixels[idx] = 10
        pixels[idx + 1] = 200
        pixels[idx + 2] = 100
        pixels[idx + 3] = 255
      end
      idx += 4
      i += 1
    end

    slice = Slice(UInt8).new(pixels.size)
    i = 0
    while i < pixels.size
      slice[i] = pixels[i]
      i += 1
    end

    ct1 = PrismatIQ.get_palette_color_thief_from_buffer(slice, width, height, 5, 1, 1)
    ct4 = PrismatIQ.get_palette_color_thief_from_buffer(slice, width, height, 5, 1, 4)

    ct1.should eq(ct4)
  end
end
