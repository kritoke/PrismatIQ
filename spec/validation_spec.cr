require "./spec_helper"

describe PrismatIQ::Utils::Validation do
  describe ".validate_file_path" do
    it "returns error for empty path" do
      result = PrismatIQ::Utils::Validation.validate_file_path("")
      result.err?.should be_true
      result.error.type.should eq(PrismatIQ::ErrorType::InvalidImagePath)
    end

    it "returns error for path with directory traversal" do
      result = PrismatIQ::Utils::Validation.validate_file_path("../secret.txt")
      result.err?.should be_true
      result.error.type.should eq(PrismatIQ::ErrorType::InvalidImagePath)
    end

    it "returns error for path with ~" do
      result = PrismatIQ::Utils::Validation.validate_file_path("~/secret.txt")
      result.err?.should be_true
      result.error.type.should eq(PrismatIQ::ErrorType::InvalidImagePath)
    end

    it "returns error for non-existent file" do
      result = PrismatIQ::Utils::Validation.validate_file_path("/tmp/nonexistent_file_12345.png")
      result.err?.should be_true
      result.error.type.should eq(PrismatIQ::ErrorType::FileNotFound)
    end

    it "returns error for unsupported format" do
      File.write("/tmp/test_unsupported.xyz", "test")
      result = PrismatIQ::Utils::Validation.validate_file_path("/tmp/test_unsupported.xyz")
      result.err?.should be_true
      result.error.type.should eq(PrismatIQ::ErrorType::UnsupportedFormat)
      File.delete("/tmp/test_unsupported.xyz")
    end
  end

  describe ".validate_options" do
    it "returns ok for valid options" do
      options = PrismatIQ::Options.new(color_count: 8, quality: 10, threads: 4)
      result = PrismatIQ::Utils::Validation.validate_options(options)
      result.ok?.should be_true
    end

    it "returns error for color_count < 1" do
      options = PrismatIQ::Options.new(color_count: 0)
      result = PrismatIQ::Utils::Validation.validate_options(options)
      result.err?.should be_true
      result.error.type.should eq(PrismatIQ::ErrorType::InvalidOptions)
      result.error.context.should eq({"field" => "color_count", "value" => "0"})
    end

    it "returns error for color_count > 256" do
      options = PrismatIQ::Options.new(color_count: 300)
      result = PrismatIQ::Utils::Validation.validate_options(options)
      result.err?.should be_true
      result.error.type.should eq(PrismatIQ::ErrorType::InvalidOptions)
    end

    it "returns error for quality < 1" do
      options = PrismatIQ::Options.new(quality: 0)
      result = PrismatIQ::Utils::Validation.validate_options(options)
      result.err?.should be_true
      result.error.type.should eq(PrismatIQ::ErrorType::InvalidOptions)
    end

    it "returns error for quality > 100" do
      options = PrismatIQ::Options.new(quality: 150)
      result = PrismatIQ::Utils::Validation.validate_options(options)
      result.err?.should be_true
      result.error.type.should eq(PrismatIQ::ErrorType::InvalidOptions)
    end

    it "returns error for negative threads" do
      options = PrismatIQ::Options.new(threads: -1)
      result = PrismatIQ::Utils::Validation.validate_options(options)
      result.err?.should be_true
      result.error.type.should eq(PrismatIQ::ErrorType::InvalidOptions)
    end
  end

  describe "Error struct" do
    it "creates file_not_found error" do
      error = PrismatIQ::Error.file_not_found("missing.png")
      error.type.should eq(PrismatIQ::ErrorType::FileNotFound)
      error.message.should contain("missing.png")
      error.context.try(&.[]("path")).should eq("missing.png")
    end

    it "creates invalid_image_path error" do
      error = PrismatIQ::Error.invalid_image_path("test.png", "invalid extension")
      error.type.should eq(PrismatIQ::ErrorType::InvalidImagePath)
      error.message.should contain("invalid extension")
    end

    it "creates unsupported_format error" do
      error = PrismatIQ::Error.unsupported_format(".xyz")
      error.type.should eq(PrismatIQ::ErrorType::UnsupportedFormat)
      error.message.should contain(".xyz")
    end

    it "creates corrupted_image error" do
      error = PrismatIQ::Error.corrupted_image("truncated file")
      error.type.should eq(PrismatIQ::ErrorType::CorruptedImage)
      error.message.should contain("truncated file")
    end

    it "creates invalid_options error" do
      error = PrismatIQ::Error.invalid_options("color_count", "0", "must be >= 1")
      error.type.should eq(PrismatIQ::ErrorType::InvalidOptions)
      error.context.try(&.[]("field")).should eq("color_count")
      error.context.try(&.[]("value")).should eq("0")
    end

    it "creates processing_failed error" do
      error = PrismatIQ::Error.processing_failed("out of memory")
      error.type.should eq(PrismatIQ::ErrorType::ProcessingFailed)
      error.message.should contain("out of memory")
    end

    it "provides string representation" do
      error = PrismatIQ::Error.file_not_found("test.png")
      error.to_s.should contain("FileNotFound")
      error.to_s.should contain("test.png")
    end

    it "includes context in string representation" do
      error = PrismatIQ::Error.invalid_options("color_count", "0", "must be >= 1")
      str = error.to_s
      str.should contain("color_count")
      str.should contain("0")
    end
  end

  describe "ErrorType enum" do
    it "has all expected values" do
      PrismatIQ::ErrorType.values.should contain(PrismatIQ::ErrorType::FileNotFound)
      PrismatIQ::ErrorType.values.should contain(PrismatIQ::ErrorType::InvalidImagePath)
      PrismatIQ::ErrorType.values.should contain(PrismatIQ::ErrorType::UnsupportedFormat)
      PrismatIQ::ErrorType.values.should contain(PrismatIQ::ErrorType::CorruptedImage)
      PrismatIQ::ErrorType.values.should contain(PrismatIQ::ErrorType::InvalidOptions)
      PrismatIQ::ErrorType.values.should contain(PrismatIQ::ErrorType::ProcessingFailed)
    end
  end

  describe ".validate_file_path edge cases" do
    it "returns error for empty (zero-byte) file" do
      File.write("/tmp/empty_file.png", "")
      result = PrismatIQ::Utils::Validation.validate_file_path("/tmp/empty_file.png")
      result.err?.should be_true
      result.error.type.should eq(PrismatIQ::ErrorType::CorruptedImage)
      File.delete("/tmp/empty_file.png")
    end

    it "returns error for system directories" do
      result = PrismatIQ::Utils::Validation.validate_file_path("/etc/passwd")
      result.err?.should be_true
      result.error.type.should eq(PrismatIQ::ErrorType::InvalidImagePath)
    end

    it "returns error for /proc filesystem" do
      result = PrismatIQ::Utils::Validation.validate_file_path("/proc/cpuinfo")
      result.err?.should be_true
      result.error.type.should eq(PrismatIQ::ErrorType::InvalidImagePath)
    end
  end
end
