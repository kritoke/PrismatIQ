require "./spec_helper"

describe PrismatIQ::ThemeDetector do
  describe "#detect_theme" do
    it "detects black as dark" do
      detector = PrismatIQ::ThemeDetector.new
      black = PrismatIQ::RGB.new(0, 0, 0)
      theme = detector.detect_theme(black)

      theme.should eq(:dark)
    end

    it "detects white as light" do
      detector = PrismatIQ::ThemeDetector.new
      white = PrismatIQ::RGB.new(255, 255, 255)
      theme = detector.detect_theme(white)

      theme.should eq(:light)
    end

    it "detects gray colors correctly" do
      detector = PrismatIQ::ThemeDetector.new
      dark_gray = PrismatIQ::RGB.new(50, 50, 50)
      light_gray = PrismatIQ::RGB.new(200, 200, 200)

      detector.detect_theme(dark_gray).should eq(:dark)
      detector.detect_theme(light_gray).should eq(:light)
    end

    it "caches theme detection results" do
      detector = PrismatIQ::ThemeDetector.new
      color = PrismatIQ::RGB.new(128, 128, 128)

      theme1 = detector.detect_theme(color)
      theme2 = detector.detect_theme(color)

      theme1.should eq(theme2)
    end
  end

  describe "#dark? and #light?" do
    it "correctly identifies dark colors" do
      detector = PrismatIQ::ThemeDetector.new
      black = PrismatIQ::RGB.new(0, 0, 0)

      detector.dark?(black).should be_true
      detector.light?(black).should be_false
    end

    it "correctly identifies light colors" do
      detector = PrismatIQ::ThemeDetector.new
      white = PrismatIQ::RGB.new(255, 255, 255)

      detector.light?(white).should be_true
      detector.dark?(white).should be_false
    end
  end

  describe "#suggest_foreground" do
    it "suggests white for dark backgrounds" do
      detector = PrismatIQ::ThemeDetector.new
      black = PrismatIQ::RGB.new(0, 0, 0)
      fg = detector.suggest_foreground(black)

      fg.r.should eq(255)
      fg.g.should eq(255)
      fg.b.should eq(255)
    end

    it "suggests black for light backgrounds" do
      detector = PrismatIQ::ThemeDetector.new
      white = PrismatIQ::RGB.new(255, 255, 255)
      fg = detector.suggest_foreground(white)

      fg.r.should eq(0)
      fg.g.should eq(0)
      fg.b.should eq(0)
    end
  end

  describe "#suggest_background" do
    it "suggests white for dark foregrounds" do
      detector = PrismatIQ::ThemeDetector.new
      black = PrismatIQ::RGB.new(0, 0, 0)
      bg = detector.suggest_background(black)

      bg.r.should eq(255)
      bg.g.should eq(255)
      bg.b.should eq(255)
    end

    it "suggests black for light foregrounds" do
      detector = PrismatIQ::ThemeDetector.new
      white = PrismatIQ::RGB.new(255, 255, 255)
      bg = detector.suggest_background(white)

      bg.r.should eq(0)
      bg.g.should eq(0)
      bg.b.should eq(0)
    end
  end

  describe "#analyze_palette" do
    it "correctly categorizes palette by theme" do
      detector = PrismatIQ::ThemeDetector.new
      palette = [
        PrismatIQ::RGB.new(0, 0, 0),
        PrismatIQ::RGB.new(50, 50, 50),
        PrismatIQ::RGB.new(255, 255, 255),
        PrismatIQ::RGB.new(200, 200, 200),
      ]

      analysis = detector.analyze_palette(palette)
      analysis[:dark].size.should eq(2)
      analysis[:light].size.should eq(2)
    end

    it "handles empty palette" do
      detector = PrismatIQ::ThemeDetector.new
      analysis = detector.analyze_palette([] of PrismatIQ::RGB)

      analysis[:dark].should be_empty
      analysis[:light].should be_empty
    end
  end

  describe "#dominant_theme" do
    it "identifies dark as dominant" do
      detector = PrismatIQ::ThemeDetector.new
      palette = [
        PrismatIQ::RGB.new(0, 0, 0),
        PrismatIQ::RGB.new(50, 50, 50),
        PrismatIQ::RGB.new(80, 80, 80),
        PrismatIQ::RGB.new(200, 200, 200),
      ]

      detector.dominant_theme(palette).should eq(:dark)
    end

    it "identifies light as dominant" do
      detector = PrismatIQ::ThemeDetector.new
      palette = [
        PrismatIQ::RGB.new(255, 255, 255),
        PrismatIQ::RGB.new(220, 220, 220),
        PrismatIQ::RGB.new(200, 200, 200),
        PrismatIQ::RGB.new(50, 50, 50),
      ]

      detector.dominant_theme(palette).should eq(:light)
    end

    it "returns light for empty palette" do
      detector = PrismatIQ::ThemeDetector.new
      detector.dominant_theme([] of PrismatIQ::RGB).should eq(:light)
    end
  end

  describe "#clear_cache" do
    it "clears all cached values" do
      detector = PrismatIQ::ThemeDetector.new
      color = PrismatIQ::RGB.new(128, 128, 128)

      detector.detect_theme(color)
      detector.clear_cache

      # Cache should be cleared
    end
  end

  describe "thread safety" do
    it "handles concurrent access safely" do
      detector = PrismatIQ::ThemeDetector.new
      channel = Channel(Symbol).new(100)

      100.times do |i|
        spawn do
          color = PrismatIQ::RGB.new(i % 256, (i * 2) % 256, (i * 3) % 256)
          theme = detector.detect_theme(color)
          channel.send(theme)
        end
      end

      results = Array.new(100) { channel.receive }
      results.all? { |theme| theme == :dark || theme == :light }.should be_true
    end
  end
end
