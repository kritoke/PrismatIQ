require "./spec_helper"

describe PrismatIQ::SVGColorExtractor do
  describe ".parse_color" do
    it "parses 6-digit hex colors" do
      if rgb = PrismatIQ::SVGColorExtractor.parse_color("#FF0000")
        rgb.r.should eq(255)
        rgb.g.should eq(0)
        rgb.b.should eq(0)
      else
        fail "Expected valid RGB color for #FF0000"
      end

      if rgb = PrismatIQ::SVGColorExtractor.parse_color("#00ff00")
        rgb.r.should eq(0)
        rgb.g.should eq(255)
        rgb.b.should eq(0)
      else
        fail "Expected valid RGB color for #00ff00"
      end
    end

    it "parses 3-digit hex colors" do
      if rgb = PrismatIQ::SVGColorExtractor.parse_color("#F00")
        rgb.r.should eq(255)
        rgb.g.should eq(0)
        rgb.b.should eq(0)
      else
        fail "Expected valid RGB color for #F00"
      end

      if rgb = PrismatIQ::SVGColorExtractor.parse_color("#0F0")
        rgb.r.should eq(0)
        rgb.g.should eq(255)
        rgb.b.should eq(0)
      else
        fail "Expected valid RGB color for #0F0"
      end
    end

    it "parses rgb() colors" do
      if rgb = PrismatIQ::SVGColorExtractor.parse_color("rgb(255, 0, 0)")
        rgb.r.should eq(255)
        rgb.g.should eq(0)
        rgb.b.should eq(0)
      else
        fail "Expected valid RGB color for rgb(255, 0, 0)"
      end

      if rgb = PrismatIQ::SVGColorExtractor.parse_color("rgb(0, 128, 255)")
        rgb.r.should eq(0)
        rgb.g.should eq(128)
        rgb.b.should eq(255)
      else
        fail "Expected valid RGB color for rgb(0, 128, 255)"
      end
    end

    it "parses rgb() with percentages" do
      if rgb = PrismatIQ::SVGColorExtractor.parse_color("rgb(100%, 0%, 0%)")
        rgb.r.should eq(255)
        rgb.g.should eq(0)
        rgb.b.should eq(0)
      else
        fail "Expected valid RGB color for rgb(100%, 0%, 0%)"
      end
    end

    it "parses rgba() colors" do
      if rgb = PrismatIQ::SVGColorExtractor.parse_color("rgba(255, 0, 0, 0.5)")
        rgb.r.should eq(255)
        rgb.g.should eq(0)
        rgb.b.should eq(0)
      else
        fail "Expected valid RGB color for rgba(255, 0, 0, 0.5)"
      end
    end

    it "parses hsl() colors" do
      if rgb = PrismatIQ::SVGColorExtractor.parse_color("hsl(0, 100%, 50%)")
        rgb.r.should eq(255)
        rgb.g.should eq(0)
        rgb.b.should eq(0)
      else
        fail "Expected valid RGB color for hsl(0, 100%, 50%)"
      end

      if rgb = PrismatIQ::SVGColorExtractor.parse_color("hsl(120, 100%, 50%)")
        rgb.r.should eq(0)
        rgb.g.should eq(255)
        rgb.b.should eq(0)
      else
        fail "Expected valid RGB color for hsl(120, 100%, 50%)"
      end
    end

    it "parses hsla() colors" do
      if rgb = PrismatIQ::SVGColorExtractor.parse_color("hsla(240, 100%, 50%, 0.5)")
        rgb.r.should eq(0)
        rgb.g.should eq(0)
        rgb.b.should eq(255)
      else
        fail "Expected valid RGB color for hsla(240, 100%, 50%, 0.5)"
      end
    end

    it "parses named colors" do
      if rgb = PrismatIQ::SVGColorExtractor.parse_color("red")
        rgb.r.should eq(255)
        rgb.g.should eq(0)
        rgb.b.should eq(0)
      else
        fail "Expected valid RGB color for red"
      end

      if rgb = PrismatIQ::SVGColorExtractor.parse_color("blue")
        rgb.r.should eq(0)
        rgb.g.should eq(0)
        rgb.b.should eq(255)
      else
        fail "Expected valid RGB color for blue"
      end

      if rgb = PrismatIQ::SVGColorExtractor.parse_color("lime")
        rgb.r.should eq(0)
        rgb.g.should eq(255)
        rgb.b.should eq(0)
      else
        fail "Expected valid RGB color for lime"
      end
    end

    it "handles currentColor" do
      if rgb = PrismatIQ::SVGColorExtractor.parse_color("currentColor")
        rgb.r.should eq(0)
        rgb.g.should eq(0)
        rgb.b.should eq(0)
      else
        fail "Expected valid RGB color for currentColor"
      end
    end

    it "returns nil for none" do
      rgb = PrismatIQ::SVGColorExtractor.parse_color("none")
      rgb.should be_nil
    end

    it "returns nil for inherit" do
      rgb = PrismatIQ::SVGColorExtractor.parse_color("inherit")
      rgb.should be_nil
    end

    it "returns nil for transparent" do
      rgb = PrismatIQ::SVGColorExtractor.parse_color("transparent")
      rgb.should be_nil
    end
  end

  describe ".extract_colors" do
    it "extracts colors from SVG string" do
      svg = %(<svg><rect fill="#FF0000"/><circle fill="rgb(0,255,0)"/></svg>)
      colors = PrismatIQ::SVGColorExtractor.extract_colors(svg)
      colors.size.should eq(2)
      colors[0].to_hex.should eq("#ff0000")
      colors[1].to_hex.should eq("#00ff00")
    end

    it "extracts colors from SVG with various formats" do
      svg = <<-SVG
        <svg>
          <rect fill="#FF0000"/>
          <circle fill="rgb(0,255,0)"/>
          <path fill="blue"/>
          <ellipse fill="rgba(0,0,255,0.5)"/>
          <text fill="hsl(120,100%,50%)"/>
          <line stroke="#FF00FF"/>
        </svg>
        SVG
      colors = PrismatIQ::SVGColorExtractor.extract_colors(svg)
      # 6 color strings but 4 unique RGB values:
      # - rgb(0,255,0) and hsl(120,100%,50%) both = #00ff00
      # - blue and rgba(0,0,255,0.5) both = #0000ff
      colors.size.should eq(4)
    end

    it "extracts stop-color from gradients" do
      svg = <<-SVG
        <svg>
          <defs>
            <linearGradient>
              <stop stop-color="#FF0000"/>
              <stop stop-color="#0000FF"/>
            </linearGradient>
          </defs>
        </svg>
        SVG
      colors = PrismatIQ::SVGColorExtractor.extract_colors(svg)
      colors.size.should eq(2)
    end

    it "ignores none and inherit values" do
      svg = <<-SVG
        <svg>
          <rect fill="none"/>
          <circle fill="inherit"/>
          <path fill="#FF0000"/>
        </svg>
        SVG
      colors = PrismatIQ::SVGColorExtractor.extract_colors(svg)
      colors.size.should eq(1)
    end

    it "deduplicates identical colors" do
      svg = <<-SVG
        <svg>
          <rect fill="#FF0000"/>
          <circle fill="#FF0000"/>
          <path fill="#FF0000"/>
        </svg>
        SVG
      colors = PrismatIQ::SVGColorExtractor.extract_colors(svg)
      colors.size.should eq(1)
    end

    it "handles inherited fill from group" do
      svg = <<-SVG
        <svg>
          <g fill="#FFFF00">
            <rect/>
            <circle/>
          </g>
        </svg>
        SVG
      colors = PrismatIQ::SVGColorExtractor.extract_colors(svg)
      colors.size.should eq(1)
      colors[0].to_hex.should eq("#ffff00")
    end
  end

  describe ".extract_from_file" do
    it "extracts colors from SVG file" do
      result = PrismatIQ::SVGColorExtractor.extract_from_file("spec/fixtures/test_colors.svg")
      result.ok?.should be_true
      colors = result.value
      colors.size.should be > 0
    end

    it "returns error for non-existent file" do
      result = PrismatIQ::SVGColorExtractor.extract_from_file("nonexistent.svg")
      result.err?.should be_true
      result.error.type.should eq(PrismatIQ::ErrorType::FileNotFound)
    end

    it "handles empty SVG file" do
      File.write("/tmp/empty.svg", "<svg></svg>")
      result = PrismatIQ::SVGColorExtractor.extract_from_file("/tmp/empty.svg")
      result.ok?.should be_true
      colors = result.value
      colors.size.should eq(0)
      File.delete("/tmp/empty.svg")
    end

    it "extracts colors from malformed but parseable XML" do
      File.write("/tmp/minimal.svg", "<svg><rect fill=\"#FF0000\"/></svg>")
      result = PrismatIQ::SVGColorExtractor.extract_from_file("/tmp/minimal.svg")
      result.ok?.should be_true
      colors = result.value
      colors.size.should eq(1)
      File.delete("/tmp/minimal.svg")
    end
  end

  describe "hsl conversion accuracy" do
    it "converts red correctly (hsl(0, 100%, 50%))" do
      if rgb = PrismatIQ::SVGColorExtractor.parse_color("hsl(0, 100%, 50%)")
        rgb.r.should eq(255)
        rgb.g.should eq(0)
        rgb.b.should eq(0)
      else
        fail "Expected valid RGB color for hsl(0, 100%, 50%)"
      end
    end

    it "converts green correctly (hsl(120, 100%, 50%))" do
      if rgb = PrismatIQ::SVGColorExtractor.parse_color("hsl(120, 100%, 50%)")
        rgb.r.should eq(0)
        rgb.g.should eq(255)
        rgb.b.should eq(0)
      else
        fail "Expected valid RGB color for hsl(120, 100%, 50%)"
      end
    end

    it "converts blue correctly (hsl(240, 100%, 50%))" do
      if rgb = PrismatIQ::SVGColorExtractor.parse_color("hsl(240, 100%, 50%)")
        rgb.r.should eq(0)
        rgb.g.should eq(0)
        rgb.b.should eq(255)
      else
        fail "Expected valid RGB color for hsl(240, 100%, 50%)"
      end
    end

    it "converts yellow correctly (hsl(60, 100%, 50%))" do
      if rgb = PrismatIQ::SVGColorExtractor.parse_color("hsl(60, 100%, 50%)")
        rgb.r.should eq(255)
        rgb.g.should eq(255)
        rgb.b.should eq(0)
      else
        fail "Expected valid RGB color for hsl(60, 100%, 50%)"
      end
    end

    it "converts gray correctly (hsl(0, 0%, 50%))" do
      if rgb = PrismatIQ::SVGColorExtractor.parse_color("hsl(0, 0%, 50%)")
        rgb.r.should eq(128)
        rgb.g.should eq(128)
        rgb.b.should eq(128)
      else
        fail "Expected valid RGB color for hsl(0, 0%, 50%)"
      end
    end

    it "converts white correctly (hsl(0, 0%, 100%))" do
      if rgb = PrismatIQ::SVGColorExtractor.parse_color("hsl(0, 0%, 100%)")
        rgb.r.should eq(255)
        rgb.g.should eq(255)
        rgb.b.should eq(255)
      else
        fail "Expected valid RGB color for hsl(0, 0%, 100%)"
      end
    end

    it "converts black correctly (hsl(0, 0%, 0%))" do
      if rgb = PrismatIQ::SVGColorExtractor.parse_color("hsl(0, 0%, 0%)")
        rgb.r.should eq(0)
        rgb.g.should eq(0)
        rgb.b.should eq(0)
      else
        fail "Expected valid RGB color for hsl(0, 0%, 0%)"
      end
    end
  end
end
