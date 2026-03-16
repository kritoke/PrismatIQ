require "./spec_helper"
require "../src/prismatiq"

describe PrismatIQ::ThemeResult do
  describe "#initialize" do
    it "creates from bg string and text hash" do
      result = PrismatIQ::ThemeResult.new("rgb(100, 150, 200)", {"light" => "#ffffff", "dark" => "#000000"})
      result.bg.should eq("rgb(100, 150, 200)")
      result.text["light"].should eq("#ffffff")
      result.text["dark"].should eq("#000000")
    end

    it "creates from RGB array and text colors" do
      result = PrismatIQ::ThemeResult.new([100, 150, 200], "#ffffff", "#000000")
      result.bg.should eq("rgb(100, 150, 200)")
      result.text["light"].should eq("#ffffff")
      result.text["dark"].should eq("#000000")
    end
  end

  describe "#to_json" do
    it "serializes to JSON" do
      result = PrismatIQ::ThemeResult.new([100, 150, 200], "#ffffff", "#000000")
      json = result.to_json
      json.should contain("\"bg\":\"rgb(100, 150, 200)\"")
      json.should contain("\"text\":{")
      json.should contain("\"light\":\"#ffffff\"")
      json.should contain("\"dark\":\"#000000\"")
    end
  end

  describe ".from_json" do
    it "parses valid JSON" do
      json = "{\"bg\":\"rgb(100, 150, 200)\",\"text\":{\"light\":\"#ffffff\",\"dark\":\"#000000\"}}"
      result = PrismatIQ::ThemeResult.from_json(json)
      result.should_not be_nil
      result.bg.should eq("rgb(100, 150, 200)")
      result.text["light"].should eq("#ffffff")
      result.text["dark"].should eq("#000000")
    end

    it "returns nil for invalid JSON" do
      result = PrismatIQ::ThemeResult.from_json("invalid json")
      result.should be_nil
    end
  end
end

describe PrismatIQ::ThemeExtractor do
  describe "#extract_from_file" do
    it "extracts theme from valid ICO file" do
      extractor = PrismatIQ::ThemeExtractor.new
      result = extractor.extract_from_file("spec/fixtures/ico/png_icon_32x32.ico")
      result.should_not be_nil
      result.bg.should start_with("rgb(")
      result.text.has_key?("light").should be_true
      result.text.has_key?("dark").should be_true
    end

    it "extracts theme from valid PNG file" do
      extractor = PrismatIQ::ThemeExtractor.new
      result = extractor.extract_from_file("spec/fixtures/ico/golden_png_32.png")
      result.should_not be_nil
      result.bg.should start_with("rgb(")
      result.text.has_key?("light").should be_true
      result.text.has_key?("dark").should be_true
    end

    it "returns nil for non-existent file" do
      extractor = PrismatIQ::ThemeExtractor.new
      result = extractor.extract_from_file("nonexistent.png")
      result.should be_nil
    end
  end

  describe "#fix_theme" do
    it "corrects non-compliant theme" do
      extractor = PrismatIQ::ThemeExtractor.new
      theme_json = "{\"bg\":\"#ffffff\",\"text\":{\"light\":\"#ffffff\",\"dark\":\"#000000\"}}"
      result = extractor.fix_theme(theme_json)
      result.should_not be_nil

      corrected = PrismatIQ::ThemeResult.from_json(result)
      corrected.should_not be_nil
    end

    it "preserves already compliant theme" do
      extractor = PrismatIQ::ThemeExtractor.new
      theme_json = "{\"bg\":\"#000000\",\"text\":{\"light\":\"#ffffff\",\"dark\":\"#ffffff\"}}"
      result = extractor.fix_theme(theme_json)
      result.should_not be_nil
    end
  end

  describe "#clear_cache" do
    it "clears the cache without error" do
      extractor = PrismatIQ::ThemeExtractor.new
      extractor.clear_cache
    end
  end
end

describe PrismatIQ do
  describe ".extract_theme" do
    it "extracts theme using global extractor" do
      result = PrismatIQ.extract_theme("spec/fixtures/ico/golden_png_32.png")
      result.should_not be_nil
      result.bg.should start_with("rgb(")
    end

    it "respects skip_if_configured option" do
      options = PrismatIQ::ThemeOptions.new
      options.skip_if_configured = "#ff0000"
      result = PrismatIQ.extract_theme("spec/fixtures/ico/golden_png_32.png", options)
      result.should be_nil
    end
  end

  describe ".fix_theme" do
    it "fixes theme using global extractor" do
      theme_json = "{\"bg\":\"#808080\",\"text\":{\"light\":\"#ffffff\",\"dark\":\"#000000\"}}"
      result = PrismatIQ.fix_theme(theme_json)
      result.should_not be_nil
    end
  end

  describe ".clear_theme_cache" do
    it "clears global cache without error" do
      PrismatIQ.clear_theme_cache
    end
  end
end
