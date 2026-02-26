require "../spec_helper"

describe "PrismatIQ ICO helper" do
  it "parses PNG-encoded ICO entries without raising" do
    ico_path = "spec/fixtures/ico/png_icon_32x32.ico"

    first = PrismatIQ.get_palette_from_ico(ico_path)
    second = PrismatIQ.get_palette_from_ico(ico_path)
    first.is_a?(Array).should be_true
    first.size.should be >= 1
    second.should eq first
    is_default_black = (first.size == 1 && first[0].r == 0 && first[0].g == 0 && first[0].b == 0)
    is_default_black.should be_false
    expected_png_hex = ["#4f0231", "#3b1217", "#1f1e1d", "#2a024b"]
    first.map(&.to_hex).should eq expected_png_hex
  end

  it "handles BMP/DIB ICO entries (written by CrImage) without raising" do
    Dir.mkdir("spec/fixtures/ico") rescue nil

    bmp_ico_path = "spec/fixtures/ico/bmp_icon_16x16.ico"
    img = CrImage.rgba(16, 16, CrImage::Color::BLUE)
    # Write using CrImage's ICO writer (produces BMP/DIB entries)
    CrImage::ICO.write(bmp_ico_path, img)

    begin
      first = PrismatIQ.get_palette_from_ico(bmp_ico_path)
      second = PrismatIQ.get_palette_from_ico(bmp_ico_path)
      first.is_a?(Array).should be_true
      first.size.should be >= 1
      second.should eq first
      # Assert expected hex for the BMP fixture (blue)
      expected_bmp_hex = ["#300851"]
      first.map(&.to_hex).should eq expected_bmp_hex
    ensure
      File.delete(bmp_ico_path) rescue nil
    end
  end
end
