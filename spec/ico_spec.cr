require "./spec_helper"

describe "ICO support" do
  it "returns result type with error for non-existent file" do
    result = PrismatIQ.get_palette_from_ico_v2("nonexistent.ico")
    result.err?.should be_true
    result.error.message.should contain("Failed to read ICO file")
  end
end