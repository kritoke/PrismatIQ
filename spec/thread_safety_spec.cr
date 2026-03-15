require "./spec_helper"

describe "Thread Safety" do
  describe "HistogramPool" do
    it "handles concurrent access safely" do
      pool = PrismatIQ::Core::HistogramPool.new(5)
      channel = Channel(Int32).new(5)

      5.times do |i|
        spawn do
          histo = pool.acquire(i)
          # Do some work to simulate contention
          sleep(1.millisecond) if i % 2 == 0
          histo[0] = (i + 1).to_u32
          result = histo[0].to_i32
          channel.send(result)
        end
      end

      results = [] of Int32
      5.times do
        results << channel.receive
      end

      # Each histogram should have been modified independently
      results.sort!
      results.should eq([1, 2, 3, 4, 5])
    end
  end

  describe "PaletteExtractor" do
    it "produces consistent results with parallel processing" do
      # Create a test image
      width = 100
      height = 100
      pixels = Slice(UInt8).new(width * height * 4)

      # Fill with a gradient pattern
      idx = 0
      height.times do |y|
        width.times do |x|
          r = ((x * 255) / width).to_u8
          g = ((y * 255) / height).to_u8
          b = (((x + y) * 255) / (width + height)).to_u8
          a = 255_u8
          pixels[idx] = r
          pixels[idx + 1] = g
          pixels[idx + 2] = b
          pixels[idx + 3] = a
          idx += 4
        end
      end

      options = PrismatIQ::Options.new(color_count: 5, threads: 4)
      results = [] of Array(PrismatIQ::RGB)

      # Run extraction multiple times
      5.times do
        result = PrismatIQ.get_palette_v2!(pixels, width, height, options)
        results << result
      end

      # All results should be identical
      first_result = results[0]
      results.each do |result|
        result.should eq(first_result)
      end
    end

    it "handles concurrent extractions safely" do
      # Create two different test images
      width1 = 100
      height1 = 100
      pixels1 = Slice(UInt8).new(width1 * height1 * 4)

      width2 = 100
      height2 = 100
      pixels2 = Slice(UInt8).new(width2 * height2 * 4)

      # Fill with different patterns - solid colors
      idx = 0
      (width1 * height1).times do
        pixels1[idx] = 255_u8 # Red
        pixels1[idx + 1] = 0_u8
        pixels1[idx + 2] = 0_u8
        pixels1[idx + 3] = 255_u8
        idx += 4
      end

      idx = 0
      (width2 * height2).times do
        pixels2[idx] = 0_u8 # Blue
        pixels2[idx + 1] = 0_u8
        pixels2[idx + 2] = 255_u8
        pixels2[idx + 3] = 255_u8
        idx += 4
      end

      options = PrismatIQ::Options.new(color_count: 1, threads: 1)
      channel1 = Channel(Array(PrismatIQ::RGB)).new(1)
      channel2 = Channel(Array(PrismatIQ::RGB)).new(1)

      # Concurrent extractions
      spawn do
        result1 = PrismatIQ.get_palette_v2!(pixels1, width1, height1, options)
        channel1.send(result1)
      end

      spawn do
        result2 = PrismatIQ.get_palette_v2!(pixels2, width2, height2, options)
        channel2.send(result2)
      end

      final1 = channel1.receive
      final2 = channel2.receive

      # Results should be correct for each image
      final1.size.should eq(1)
      final1[0].r.should be > 200 # Predominantly red
      final1[0].g.should be < 50
      final1[0].b.should be < 50

      final2.size.should eq(1)
      final2[0].r.should be < 50 # Predominantly blue
      final2[0].g.should be < 50
      final2[0].b.should be > 200
    end
  end

  describe "ThemeExtractor singleton" do
    it "returns same instance from concurrent access" do
      instances = Channel(PrismatIQ::ThemeExtractor).new(10)

      10.times do
        spawn do
          instances.send(PrismatIQ::ThemeExtractor.instance)
        end
      end

      first_instance = instances.receive
      9.times do
        instances.receive.should be(first_instance)
      end
    end
  end
end
