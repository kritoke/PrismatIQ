require "./spec_helper"
require "../src/prismatiq"

describe "Palette stats and ColorThief compatibility" do
  it "returns entries with counts and percentages that sum to ~1 and hex format" do
    fixture = File.join(__DIR__, "fixtures", "palette_stats_a_4x4.bin")
    slice, width, height = load_rgba_fixture(fixture)

    options = PrismatIQ::Options.new(3, 1, 1)
    entries, total = PrismatIQ.get_palette_with_stats(slice, width, height, options)

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
    fixture = File.join(__DIR__, "fixtures", "palette_stats_b_4x4.bin")
    slice, width, height = load_rgba_fixture(fixture)

    options = PrismatIQ::Options.new(4, 1, 1)
    entries, _ = PrismatIQ.get_palette_with_stats(slice, width, height, options)
    ct = PrismatIQ.get_palette_color_thief(slice, width, height, options)

    expected = entries.map(&.rgb.to_hex)
    ct.should eq(expected)
  end

  it "color thief wrapper is deterministic across thread counts" do
    fixture = File.join(__DIR__, "fixtures", "palette_threads_8x8.bin")
    slice, width, height = load_rgba_fixture(fixture)

    options_single = PrismatIQ::Options.new(5, 1, 1)
    options_multi = PrismatIQ::Options.new(5, 1, 4)
    ct1 = PrismatIQ.get_palette_color_thief(slice, width, height, options_single)
    ct4 = PrismatIQ.get_palette_color_thief(slice, width, height, options_multi)

    ct1.should eq(ct4)
  end
end
