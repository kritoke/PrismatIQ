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
    first.size.should eq(5)
  end

  it "handles BMP/DIB ICO entries (written by CrImage) without raising" do
    Dir.mkdir("spec/fixtures/ico") rescue nil

    bmp_ico_path = "spec/fixtures/ico/bmp_icon_16x16.ico"
    img = CrImage.rgba(16, 16, CrImage::Color::BLUE)
    CrImage::ICO.write(bmp_ico_path, img)

    begin
      first = PrismatIQ.get_palette_from_ico(bmp_ico_path)
      second = PrismatIQ.get_palette_from_ico(bmp_ico_path)
      first.is_a?(Array).should be_true
      first.size.should be >= 1
      second.should eq first
      first[0].b.should be > first[0].r
      first[0].b.should be > first[0].g
    ensure
      File.delete(bmp_ico_path) rescue nil
    end
  end

  it "returns Result type from get_palette_from_ico_or_error" do
    ico_path = "spec/fixtures/ico/png_icon_32x32.ico"
    
    first_result = PrismatIQ.get_palette_from_ico_or_error(ico_path)
    second_result = PrismatIQ.get_palette_from_ico_or_error(ico_path)

    first_result.ok?.should be_true
    second_result.ok?.should be_true

    first = first_result.value
    second = second_result.value

    first.is_a?(Array).should be_true
    first.size.should be >= 1
    second.should eq first
  end
end
