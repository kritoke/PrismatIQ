require "../spec_helper"

describe "PrismatIQ ICO helper" do
  it "parses PNG-encoded ICO entries without raising" do
    ico_path = "spec/fixtures/ico/png_icon_32x32.ico"

    result = PrismatIQ.get_palette_from_ico_v2(ico_path)
    result.ok?.should be_true
    palette = result.value

    palette.is_a?(Array).should be_true
    palette.size.should be >= 1
    palette.size.should eq(5)
  end

  it "handles BMP/DIB ICO entries (written by CrImage) without raising" do
    Dir.mkdir("spec/fixtures/ico") rescue nil

    bmp_ico_path = "spec/fixtures/ico/bmp_icon_16x16.ico"
    img = CrImage.rgba(16, 16, CrImage::Color::BLUE)
    CrImage::ICO.write(bmp_ico_path, img)

    begin
      result = PrismatIQ.get_palette_from_ico_v2(bmp_ico_path)
      result.ok?.should be_true
      palette = result.value

      palette.is_a?(Array).should be_true
      palette.size.should be >= 1
      palette[0].b.should be > palette[0].r
      palette[0].b.should be > palette[0].g
    ensure
      File.delete(bmp_ico_path) rescue nil
    end
  end
end