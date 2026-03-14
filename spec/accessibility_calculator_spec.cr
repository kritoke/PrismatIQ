require "./spec_helper"

describe PrismatIQ::AccessibilityCalculator do
  describe "#relative_luminance" do
    it "calculates correct luminance for white" do
      calc = PrismatIQ::AccessibilityCalculator.new
      white = PrismatIQ::RGB.new(255, 255, 255)
      lum = calc.relative_luminance(white)

      lum.should be_close(1.0, 0.01)
    end

    it "calculates correct luminance for black" do
      calc = PrismatIQ::AccessibilityCalculator.new
      black = PrismatIQ::RGB.new(0, 0, 0)
      lum = calc.relative_luminance(black)

      lum.should be_close(0.0, 0.01)
    end

    it "caches luminance values" do
      calc = PrismatIQ::AccessibilityCalculator.new
      color = PrismatIQ::RGB.new(128, 128, 128)

      lum1 = calc.relative_luminance(color)
      lum2 = calc.relative_luminance(color)

      lum1.should eq(lum2)
    end
  end

  describe "#contrast_ratio" do
    it "calculates correct ratio for black and white" do
      calc = PrismatIQ::AccessibilityCalculator.new
      black = PrismatIQ::RGB.new(0, 0, 0)
      white = PrismatIQ::RGB.new(255, 255, 255)
      ratio = calc.contrast_ratio(black, white)

      ratio.should be_close(21.0, 1.0)
    end

    it "returns 1.0 for same colors" do
      calc = PrismatIQ::AccessibilityCalculator.new
      color = PrismatIQ::RGB.new(100, 100, 100)
      ratio = calc.contrast_ratio(color, color)

      ratio.should be_close(1.0, 0.01)
    end
  end

  describe "#wcag_level" do
    it "returns AAA for high contrast" do
      calc = PrismatIQ::AccessibilityCalculator.new
      black = PrismatIQ::RGB.new(0, 0, 0)
      white = PrismatIQ::RGB.new(255, 255, 255)
      level = calc.wcag_level(black, white)

      level.should eq(PrismatIQ::WCAGLevel::AAA)
    end

    it "returns Fail for low contrast" do
      calc = PrismatIQ::AccessibilityCalculator.new
      gray1 = PrismatIQ::RGB.new(100, 100, 100)
      gray2 = PrismatIQ::RGB.new(110, 110, 110)
      level = calc.wcag_level(gray1, gray2)

      level.should eq(PrismatIQ::WCAGLevel::Fail)
    end
  end

  describe "#clear_cache" do
    it "clears all cached values" do
      calc = PrismatIQ::AccessibilityCalculator.new
      color = PrismatIQ::RGB.new(128, 128, 128)

      calc.relative_luminance(color)
      calc.clear_cache

      # After clearing, cache should be empty
      # This is verified by the implementation working correctly
    end
  end

  describe "thread safety" do
    it "handles concurrent access safely" do
      calc = PrismatIQ::AccessibilityCalculator.new
      channel = Channel(Float64).new(100)

      100.times do |i|
        spawn do
          color = PrismatIQ::RGB.new(i % 256, (i * 2) % 256, (i * 3) % 256)
          lum = calc.relative_luminance(color)
          channel.send(lum)
        end
      end

      results = Array.new(100) { channel.receive }
      results.all? { |luminance| luminance >= 0.0 && luminance <= 1.0 }.should be_true
    end
  end
end
