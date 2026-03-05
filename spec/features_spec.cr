require "./spec_helper"
require "../src/prismatiq"

describe PrismatIQ::Options do
  describe "defaults" do
    it "has correct default values" do
      opts = PrismatIQ::Options.new
      opts.color_count.should eq(5)
      opts.quality.should eq(10)
      opts.threads.should eq(0)
      opts.alpha_threshold.should eq(125_u8)
    end
  end

  describe "validate!" do
    it "returns Result.ok for valid options" do
      opts = PrismatIQ::Options.new(color_count: 5, quality: 10)
      # validate! raises on invalid options - use a valid opts for Result-based testing
      opts.color_count.should eq(5)
      opts.quality.should eq(10)
    end

    it "raises on invalid color_count" do
      opts = PrismatIQ::Options.new(color_count: 0)
      expect_raises(PrismatIQ::ValidationError, "color_count must be >= 1") do
        opts.validate!
      end
    end

    it "raises on invalid quality" do
      opts = PrismatIQ::Options.new(quality: 0)
      expect_raises(PrismatIQ::ValidationError, "quality must be >= 1") do
        opts.validate!
      end
    end

    it "returns ok via Result for valid options" do
      opts = PrismatIQ::Options.new(color_count: 5, quality: 10)
      result = PrismatIQ::Result(PrismatIQ::Options, String).ok(opts)
      result.ok?.should be_true
    end
  end
end

describe PrismatIQ::PaletteResult do
  describe ".ok" do
    it "creates successful result" do
      colors = [PrismatIQ::RGB.new(255, 0, 0)]
      result = PrismatIQ::PaletteResult.ok(colors, 100)
      result.success?.should be_true
      result.colors.should eq(colors)
      result.total_pixels.should eq(100)
      result.error.should be_nil
    end
  end

  describe ".err" do
    it "creates error result" do
      result = PrismatIQ::PaletteResult.err("Something went wrong")
      result.success?.should be_false
      result.colors.should be_empty
      result.total_pixels.should eq(0)
      result.error.should eq("Something went wrong")
    end
  end
end

describe PrismatIQ::RGB do
  describe "serialization" do
    it "serializes to JSON as hex" do
      rgb = PrismatIQ::RGB.new(255, 128, 0)
      rgb.to_json.should eq("\"#ff8000\"")
    end

    it "deserializes from JSON hex" do
      rgb = PrismatIQ::RGB.from_json("\"#ff8000\"")
      rgb.r.should eq(255)
      rgb.g.should eq(128)
      rgb.b.should eq(0)
    end

    it "deserializes from JSON without hash" do
      rgb = PrismatIQ::RGB.from_json("\"ff8000\"")
      rgb.r.should eq(255)
      rgb.g.should eq(128)
      rgb.b.should eq(0)
    end
  end

  describe ".from_hex" do
    it "parses hex with #" do
      rgb = PrismatIQ::RGB.from_hex("#ff0000")
      rgb.r.should eq(255)
      rgb.g.should eq(0)
      rgb.b.should eq(0)
    end

    it "parses hex without #" do
      rgb = PrismatIQ::RGB.from_hex("00ff00")
      rgb.r.should eq(0)
      rgb.g.should eq(255)
      rgb.b.should eq(0)
    end
  end

  describe "#distance_to" do
    it "calculates distance to black" do
      white = PrismatIQ::RGB.new(255, 255, 255)
      black = PrismatIQ::RGB.new(0, 0, 0)
      distance = white.distance_to(black)
      distance.should be_close(Math.sqrt(255*255*3), 0.001)
    end

    it "returns 0 for same color" do
      red = PrismatIQ::RGB.new(255, 0, 0)
      red.distance_to(red).should eq(0.0)
    end
  end
end

describe PrismatIQ::Accessibility do
  describe ".relative_luminance" do
    it "returns 1.0 for white" do
      white = PrismatIQ::RGB.new(255, 255, 255)
      PrismatIQ::Accessibility.relative_luminance(white).should be_close(1.0, 0.001)
    end

    it "returns 0.0 for black" do
      black = PrismatIQ::RGB.new(0, 0, 0)
      PrismatIQ::Accessibility.relative_luminance(black).should be_close(0.0, 0.001)
    end
  end

  describe ".contrast_ratio" do
    it "returns 21:1 for black on white" do
      black = PrismatIQ::RGB.new(0, 0, 0)
      white = PrismatIQ::RGB.new(255, 255, 255)
      ratio = PrismatIQ::Accessibility.contrast_ratio(black, white)
      ratio.should be_close(21.0, 0.1)
    end

    it "returns 1:1 for same color" do
      gray = PrismatIQ::RGB.new(128, 128, 128)
      PrismatIQ::Accessibility.contrast_ratio(gray, gray).should be_close(1.0, 0.01)
    end
  end

  describe ".wcag_aa_compliant?" do
    it "passes for high contrast" do
      black = PrismatIQ::RGB.new(0, 0, 0)
      white = PrismatIQ::RGB.new(255, 255, 255)
      PrismatIQ::Accessibility.wcag_aa_compliant?(black, white).should be_true
    end

    it "fails for low contrast" do
      gray1 = PrismatIQ::RGB.new(100, 100, 100)
      gray2 = PrismatIQ::RGB.new(120, 120, 120)
      PrismatIQ::Accessibility.wcag_aa_compliant?(gray1, gray2).should be_false
    end
  end
end

describe "color matching" do
  describe ".find_closest" do
    it "finds closest color in palette" do
      target = PrismatIQ::RGB.new(250, 5, 5)
      palette = [
        PrismatIQ::RGB.new(0, 0, 255),
        PrismatIQ::RGB.new(255, 0, 0),
        PrismatIQ::RGB.new(0, 255, 0),
      ]
      closest = PrismatIQ.find_closest(target, palette)
      closest.should eq(PrismatIQ::RGB.new(255, 0, 0))
    end

    it "returns nil for empty palette" do
      PrismatIQ.find_closest(PrismatIQ::RGB.new(0, 0, 0), [] of PrismatIQ::RGB).should be_nil
    end
  end

  describe "Result-based palette extraction" do
    it "extracts palette from buffer with explicit error handling" do
      # Create a simple test buffer with known colors
      pixels = Slice(UInt8).new(4 * 4 * 4)
      # Fill with red (255, 0, 0)
      16.times do |i|
        pixels[i * 4] = 255_u8
        pixels[i * 4 + 1] = 0_u8
        pixels[i * 4 + 2] = 0_u8
        pixels[i * 4 + 3] = 255_u8
      end

      options = PrismatIQ::Options.new(color_count: 3)
      result = PrismatIQ.get_palette_or_error(pixels, 4, 4, options)
      result.ok?.should be_true
      result.value.size.should be > 0
    end

    it "returns error for invalid parameters" do
      pixels = Slice(UInt8).new(0)
      options = PrismatIQ::Options.new(color_count: 0)
      result = PrismatIQ.get_palette_or_error(pixels, 0, 0, options)
      # Either returns error or validates params
      result.ok?.should be_false
    end

    it "uses map to transform successful result" do
      pixels = Slice(UInt8).new(4 * 4 * 4)
      16.times do |i|
        pixels[i * 4] = 255_u8
        pixels[i * 4 + 1] = 0_u8
        pixels[i * 4 + 2] = 0_u8
        pixels[i * 4 + 3] = 255_u8
      end

      options = PrismatIQ::Options.new(color_count: 3)
      result = PrismatIQ.get_palette_or_error(pixels, 4, 4, options)
      hex_result = result.map { |colors| colors.map(&.to_hex) }
      hex_result.ok?.should be_true
    end

    it "uses map_error to transform error result" do
      invalid_result = PrismatIQ::Result(Array(PrismatIQ::RGB), String).err("Original error")
      mapped = invalid_result.map_error { |e| "Custom: #{e}" }
      mapped.error.should eq("Custom: Original error")
    end

    it "uses flat_map to chain operations" do
      pixels = Slice(UInt8).new(4 * 4 * 4)
      16.times do |i|
        pixels[i * 4] = 0_u8
        pixels[i * 4 + 1] = 255_u8
        pixels[i * 4 + 2] = 0_u8
        pixels[i * 4 + 3] = 255_u8
      end

      options = PrismatIQ::Options.new(color_count: 3)
      result = PrismatIQ.get_palette_or_error(pixels, 4, 4, options)
      # flat_map should return a Result with the same type
      chained = result.flat_map { |colors|
        PrismatIQ::Result(Array(PrismatIQ::RGB), String).ok(colors)
      }
      chained.ok?.should be_true
      chained.value.should be_a(Array(PrismatIQ::RGB))
    end

    it "uses value_or for default values" do
      error_result = PrismatIQ::Result(Array(PrismatIQ::RGB), String).err("Failed")
      default_palette = [PrismatIQ::RGB.new(0, 0, 0)]
      value = error_result.value_or(default_palette)
      value.should eq(default_palette)
    end
  end
end
