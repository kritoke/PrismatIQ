require "./spec_helper"
require "../src/prismatiq/yiq_converter"

describe PrismatIQ::YIQConverter do
  describe "from_rgb" do
    it "converts white (255, 255, 255) to max brightness" do
      color = PrismatIQ::YIQConverter.from_rgb(255, 255, 255)
      color.y.should be_close(255.0, 0.01)
      color.i.should be_close(0.0, 0.01)
      color.q.should be_close(0.0, 0.01)
    end

    it "converts black (0, 0, 0) to zero brightness" do
      color = PrismatIQ::YIQConverter.from_rgb(0, 0, 0)
      color.y.should be_close(0.0, 0.01)
      color.i.should be_close(0.0, 0.01)
      color.q.should be_close(0.0, 0.01)
    end

    it "converts pure red (255, 0, 0)" do
      color = PrismatIQ::YIQConverter.from_rgb(255, 0, 0)
      # Y = 0.299 * 255 = 76.245
      color.y.should be_close(76.245, 0.01)
      # I = 0.596 * 255 = 151.98
      color.i.should be_close(151.98, 0.01)
      # Q = 0.211 * 255 = 53.805
      color.q.should be_close(53.805, 0.01)
    end

    it "converts pure green (0, 255, 0)" do
      color = PrismatIQ::YIQConverter.from_rgb(0, 255, 0)
      # Y = 0.587 * 255 = 149.685
      color.y.should be_close(149.685, 0.01)
      # I = -0.274 * 255 = -69.87
      color.i.should be_close(-69.87, 0.01)
      # Q = -0.523 * 255 = -133.365
      color.q.should be_close(-133.365, 0.01)
    end

    it "converts pure blue (0, 0, 255)" do
      color = PrismatIQ::YIQConverter.from_rgb(0, 0, 255)
      # Y = 0.114 * 255 = 29.07
      color.y.should be_close(29.07, 0.01)
      # I = -0.322 * 255 = -82.11
      color.i.should be_close(-82.11, 0.01)
      # Q = 0.312 * 255 = 79.56
      color.q.should be_close(79.56, 0.01)
    end

    it "converts cyan (0, 255, 255)" do
      color = PrismatIQ::YIQConverter.from_rgb(0, 255, 255)
      color.y.should be_close(178.755, 0.01)
      color.i.should be_close(-151.98, 0.01)
      color.q.should be_close(-53.805, 0.01)
    end

    it "converts magenta (255, 0, 255)" do
      color = PrismatIQ::YIQConverter.from_rgb(255, 0, 255)
      color.y.should be_close(105.315, 0.01)
      color.i.should be_close(69.87, 0.01)
      color.q.should be_close(133.365, 0.01)
    end

    it "converts yellow (255, 255, 0)" do
      color = PrismatIQ::YIQConverter.from_rgb(255, 255, 0)
      color.y.should be_close(225.93, 0.01)
      color.i.should be_close(82.11, 0.01)
      color.q.should be_close(-79.56, 0.01)
    end

    it "converts gray (128, 128, 128)" do
      color = PrismatIQ::YIQConverter.from_rgb(128, 128, 128)
      # Y = 0.299*128 + 0.587*128 + 0.114*128 = 38.272 + 75.136 + 14.592 = 128
      color.y.should be_close(128.0, 0.01)
      color.i.should be_close(0.0, 0.01)
      color.q.should be_close(0.0, 0.01)
    end

    it "handles mid-range values (100, 150, 200)" do
      color = PrismatIQ::YIQConverter.from_rgb(100, 150, 200)
      # Y = 0.299*100 + 0.587*150 + 0.114*200 = 29.9 + 88.05 + 22.8 = 140.75
      color.y.should be_close(140.75, 0.01)
    end
  end

  describe "quantize_from_rgb" do
    # The quantization now properly scales YIQ values to 0-31 range:
    # - Y: [0, 255] -> [0, 31]
    # - I: [-152, 152] -> [0, 31]
    # - Q: [-134, 134] -> [0, 31]

    it "quantizes white correctly" do
      y, i, q = PrismatIQ::YIQConverter.quantize_from_rgb(255, 255, 255)
      # White: Y=255 -> 31, I=0 -> 16 (midpoint), Q=0 -> 16 (midpoint)
      y.should eq(31)
      i.should eq(16)
      q.should eq(16)
    end

    it "quantizes black correctly" do
      y, i, q = PrismatIQ::YIQConverter.quantize_from_rgb(0, 0, 0)
      # Black: Y=0 -> 0, I=0 -> 16 (midpoint), Q=0 -> 16 (midpoint)
      y.should eq(0)
      i.should eq(16)
      q.should eq(16)
    end

    it "quantizes pure red correctly" do
      y, i, q = PrismatIQ::YIQConverter.quantize_from_rgb(255, 0, 0)
      # Red: Y=76.245 -> 9, I=151.98 -> 31, Q=53.805 -> 22
      y.should eq(9)
      i.should eq(31)
      q.should eq(22)
    end

    it "quantizes pure green correctly" do
      y, i, q = PrismatIQ::YIQConverter.quantize_from_rgb(0, 255, 0)
      # Green: Y=149.685 -> 18, I=-69.87 -> 8, Q=-133.365 -> 0
      y.should eq(18)
      i.should eq(8)
      q.should eq(0)
    end

    it "quantizes pure blue correctly" do
      y, i, q = PrismatIQ::YIQConverter.quantize_from_rgb(0, 0, 255)
      # Blue: Y=29.07 -> 4, I=-82.11 -> 7, Q=79.56 -> 25
      y.should eq(4)
      i.should eq(7)
      q.should eq(25)
    end

    it "handles gray correctly (neutral colors have I and Q at midpoint)" do
      y, i, q = PrismatIQ::YIQConverter.quantize_from_rgb(128, 128, 128)
      # Gray: Y=128 -> 16, I=0 -> 16, Q=0 -> 16
      y.should eq(16)
      i.should eq(16)
      q.should eq(16)
    end

    it "quantizes cyan correctly" do
      y, i, q = PrismatIQ::YIQConverter.quantize_from_rgb(0, 255, 255)
      # Cyan: Y=178.755 -> 22, I=-151.98 -> 0, Q=-53.805 -> 9
      y.should eq(22)
      i.should eq(0)
      q.should eq(9)
    end

    it "quantizes magenta correctly" do
      y, i, q = PrismatIQ::YIQConverter.quantize_from_rgb(255, 0, 255)
      # Magenta: Y=105.315 -> 13, I=69.87 -> 23, Q=133.365 -> 31
      y.should eq(13)
      i.should eq(23)
      q.should eq(31)
    end

    it "quantizes yellow correctly" do
      y, i, q = PrismatIQ::YIQConverter.quantize_from_rgb(255, 255, 0)
      # Yellow: Y=225.93 -> 27, I=82.11 -> 24, Q=-79.56 -> 6
      y.should eq(27)
      i.should eq(24)
      q.should eq(6)
    end

    it "returns consistent results for same input" do
      result1 = PrismatIQ::YIQConverter.quantize_from_rgb(100, 150, 200)
      result2 = PrismatIQ::YIQConverter.quantize_from_rgb(100, 150, 200)
      result1.should eq(result2)
    end

    it "returns values within valid range" do
      # Test various colors to ensure all values are 0-31
      test_colors = [
        {0, 0, 0},
        {255, 255, 255},
        {255, 0, 0},
        {0, 255, 0},
        {0, 0, 255},
        {128, 128, 128},
        {100, 150, 200},
        {50, 75, 100},
        {255, 128, 0},
        {0, 128, 255},
      ]

      test_colors.each do |r, g, b|
        y, i, q = PrismatIQ::YIQConverter.quantize_from_rgb(r, g, b)
        y.should be >= 0
        y.should be <= 31
        i.should be >= 0
        i.should be <= 31
        q.should be >= 0
        q.should be <= 31
      end
    end

    it "handles minimum RGB values (0, 0, 0)" do
      y, i, q = PrismatIQ::YIQConverter.quantize_from_rgb(0, 0, 0)
      y.should eq(0)
      i.should eq(16)
      q.should eq(16)
    end

    it "handles maximum RGB values (255, 255, 255)" do
      y, i, q = PrismatIQ::YIQConverter.quantize_from_rgb(255, 255, 255)
      y.should eq(31)
      i.should eq(16)
      q.should eq(16)
    end

    it "handles mid-range RGB values (100, 100, 100)" do
      y, i, q = PrismatIQ::YIQConverter.quantize_from_rgb(100, 100, 100)
      # Y = 0.299*100 + 0.587*100 + 0.114*100 = 100 -> 12
      y.should eq(12)
      i.should eq(16)
      q.should eq(16)
    end
  end

  describe "to_index" do
    it "converts zero values to index 0" do
      index = PrismatIQ::YIQConverter.to_index(0, 0, 0)
      index.should eq(0)
    end

    it "converts max quantized values to max index" do
      index = PrismatIQ::YIQConverter.to_index(31, 31, 31)
      # (31 << 10) | (31 << 5) | 31 = 31744 | 992 | 31 = 32767
      index.should eq(32767)
    end

    it "converts (1, 0, 0) correctly" do
      index = PrismatIQ::YIQConverter.to_index(1, 0, 0)
      # (1 << 10) | (0 << 5) | 0 = 1024
      index.should eq(1024)
    end

    it "converts (0, 1, 0) correctly" do
      index = PrismatIQ::YIQConverter.to_index(0, 1, 0)
      # (0 << 10) | (1 << 5) | 0 = 32
      index.should eq(32)
    end

    it "converts (0, 0, 1) correctly" do
      index = PrismatIQ::YIQConverter.to_index(0, 0, 1)
      # (0 << 10) | (0 << 5) | 1 = 1
      index.should eq(1)
    end

    it "converts (1, 1, 1) correctly" do
      index = PrismatIQ::YIQConverter.to_index(1, 1, 1)
      # (1 << 10) | (1 << 5) | 1 = 1024 | 32 | 1 = 1057
      index.should eq(1057)
    end

    it "converts (10, 20, 5) correctly" do
      index = PrismatIQ::YIQConverter.to_index(10, 20, 5)
      # (10 << 10) | (20 << 5) | 5 = 10240 | 640 | 5 = 10885
      index.should eq(10885)
    end

    it "is the inverse of from_rgb -> quantize for white" do
      y, i, q = PrismatIQ::YIQConverter.quantize_from_rgb(255, 255, 255)
      index = PrismatIQ::YIQConverter.to_index(y, i, q)
      # White: Y=31, I=16, Q=16
      # (31 << 10) | (16 << 5) | 16 = 31744 | 512 | 16 = 32272
      index.should eq(32272)
    end

    it "is the inverse of from_rgb -> quantize for red" do
      y, i, q = PrismatIQ::YIQConverter.quantize_from_rgb(255, 0, 0)
      index = PrismatIQ::YIQConverter.to_index(y, i, q)
      # Red: Y=9, I=31, Q=22
      # (9 << 10) | (31 << 5) | 22 = 9216 | 992 | 22 = 10230
      index.should eq(10230)
    end

    it "produces unique indices for different Y values" do
      indices = (0..31).map { |y| PrismatIQ::YIQConverter.to_index(y, 0, 0) }
      indices.uniq.size.should eq(32)
    end

    it "produces unique indices for different I values" do
      indices = (0..31).map { |i| PrismatIQ::YIQConverter.to_index(0, i, 0) }
      indices.uniq.size.should eq(32)
    end

    it "produces unique indices for different Q values" do
      indices = (0..31).map { |q| PrismatIQ::YIQConverter.to_index(0, 0, q) }
      indices.uniq.size.should eq(32)
    end
  end

  describe "round-trip conversion" do
    it "converts RGB -> quantize -> index consistently" do
      # Any RGB input should produce a consistent index
      rgb_values = [
        {0, 0, 0},
        {255, 255, 255},
        {255, 0, 0},
        {0, 255, 0},
        {0, 0, 255},
        {128, 128, 128},
        {100, 150, 200},
        {50, 75, 100},
      ]

      rgb_values.each do |r, g, b|
        y, i, q = PrismatIQ::YIQConverter.quantize_from_rgb(r, g, b)
        index = PrismatIQ::YIQConverter.to_index(y, i, q)
        
        # Verify the index is within valid range
        index.should be >= 0
        index.should be <= 32767
        
        # Verify second call produces same result
        y2, i2, q2 = PrismatIQ::YIQConverter.quantize_from_rgb(r, g, b)
        index2 = PrismatIQ::YIQConverter.to_index(y2, i2, q2)
        index.should eq(index2)
      end
    end

    it "maps to a reasonable number of histogram indices for diverse colors" do
      # Test a wide range of colors to ensure we cover the histogram space
      indices = [] of Int32
      
      # Sample various colors across the RGB space
      r_step = 17
      g_step = 17
      b_step = 17
      
      r = 0
      while r <= 255
        g = 0
        while g <= 255
          b = 0
          while b <= 255
            y, i, q = PrismatIQ::YIQConverter.quantize_from_rgb(r, g, b)
            index = PrismatIQ::YIQConverter.to_index(y, i, q)
            indices << index
            b += b_step
          end
          g += g_step
        end
        r += r_step
      end
      
      # With proper scaling, we should have good distribution
      indices.uniq.size.should be > 100
    end
  end
end
