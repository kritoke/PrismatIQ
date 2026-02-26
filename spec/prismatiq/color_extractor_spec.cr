require "../spec_helper"

describe PrismatIQ::ColorExtractor do
  it "extracts dominant color from a simple solid buffer" do
    # Load canonical fixture for a 4x4 solid buffer
    fixture = File.join(__DIR__, "..", "fixtures", "solid_4x4_rgba.bin")
    pixels, width, height = load_rgba_fixture(fixture)

    rgb = PrismatIQ.extract_from_buffer(pixels, width, height)
    rgb.should_not be_nil
    rgb.should eq [120, 200, 40]
  end

  it "returns nil for non-positive dimensions" do
    fixture = File.join(__DIR__, "..", "fixtures", "transparent_2x1.bin")
    pixels, _, _ = load_rgba_fixture(fixture)
    rgb = PrismatIQ.extract_from_buffer(pixels, 0_i32, 10_i32)
    rgb.should be_nil
  end

  it "ignores fully transparent pixels by default" do
    fixture = File.join(__DIR__, "..", "fixtures", "transparent_2x1.bin")
    pixels, width, height = load_rgba_fixture(fixture)

    rgb = PrismatIQ.extract_from_buffer(pixels, width, height)
    rgb.should eq [10, 20, 30]
  end

  it "unpremultiplies partially transparent pixels correctly" do
    fixture = File.join(__DIR__, "..", "fixtures", "unpremult_1x1.bin")
    pixels, width, height = load_rgba_fixture(fixture)

    rgb = PrismatIQ.extract_from_buffer(pixels, width, height)
    rgb.should_not be_nil
    # Expect integer unpremultiplied result (rounded down in implementation)
    rgb.should eq [199, 99, 49]
  end

  it "is deterministic for repeated calls on the same buffer" do
    fixture = File.join(__DIR__, "..", "fixtures", "checker_10x10.bin")
    first_pixels, width, height = load_rgba_fixture(fixture)

    first = PrismatIQ.extract_from_buffer(first_pixels, width, height)
    second = PrismatIQ.extract_from_buffer(first_pixels, width, height)
    first.should eq second
    first.should eq [127, 127, 0]
  end
end
