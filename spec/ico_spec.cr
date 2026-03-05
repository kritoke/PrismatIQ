require "./spec_helper"

describe "ICO support" do
  it "returns result type with error for non-existent file" do
    result = PrismatIQ.get_palette_from_ico_or_error("nonexistent.ico")
    result.err?.should be_true
    result.error.should contain("Failed to extract palette")
  end

  it "returns sentinel array for non-existent file (convenience API)" do
    palette = PrismatIQ.get_palette_from_ico("nonexistent.ico")
    palette.size.should eq(1)
    palette[0].r.should eq(0)
    palette[0].g.should eq(0)
    palette[0].b.should eq(0)
  end
end
