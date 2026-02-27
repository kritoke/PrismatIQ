require "./spec_helper"

describe PrismatIQ::Result(Int32, String) do
  describe ".ok" do
    it "creates a successful result" do
      result = PrismatIQ::Result(Int32, String).ok(42)
      result.ok?.should be_true
      result.err?.should be_false
      result.value.should eq(42)
    end
  end

  describe ".err" do
    it "creates an error result" do
      result = PrismatIQ::Result(Int32, String).err("oops")
      result.ok?.should be_false
      result.err?.should be_true
      result.error.should eq("oops")
    end
  end

  describe "#value_or" do
    it "returns value when ok" do
      result = PrismatIQ::Result(Int32, String).ok(42)
      result.value_or(0).should eq(42)
    end

    it "returns default when error" do
      result = PrismatIQ::Result(Int32, String).err("oops")
      result.value_or(0).should eq(0)
    end
  end

  describe "#map" do
    it "transforms the value when ok" do
      result = PrismatIQ::Result(Int32, String).ok(21)
      mapped = result.map { |x| x * 2 }
      mapped.value.should eq(42)
    end

    it "preserves error when err" do
      result = PrismatIQ::Result(Int32, String).err("oops")
      mapped = result.map { |x| x * 2 }
      mapped.err?.should be_true
      mapped.error.should eq("oops")
    end
  end

  describe "#flat_map" do
    it "chains successful results" do
      result = PrismatIQ::Result(Int32, String).ok(21)
      chained = result.flat_map { |x| PrismatIQ::Result(Int32, String).ok(x * 2) }
      chained.value.should eq(42)
    end

    it "preserves error" do
      result = PrismatIQ::Result(Int32, String).err("oops")
      chained = result.flat_map { |x| PrismatIQ::Result(Int32, String).ok(x * 2) }
      chained.error.should eq("oops")
    end
  end

  describe "#map_error" do
    it "transforms the error" do
      result = PrismatIQ::Result(Int32, String).err("oops")
      mapped = result.map_error { |e| "Error: #{e}" }
      mapped.error.should eq("Error: oops")
    end

    it "preserves value when ok" do
      result = PrismatIQ::Result(Int32, String).ok(42)
      mapped = result.map_error { |e| "Error: #{e}" }
      mapped.value.should eq(42)
    end
  end
end

describe PrismatIQ::Config do
  describe ".default" do
    it "returns a Config instance" do
      config = PrismatIQ::Config.default
      config.should be_a(PrismatIQ::Config)
    end
  end

  describe "#thread_count_for" do
    it "uses requested value when positive" do
      config = PrismatIQ::Config.new(threads: 4)
      config.thread_count_for(100, 2).should eq(2)
    end

    it "uses config.threads when requested is 0" do
      config = PrismatIQ::Config.new(threads: 8)
      config.thread_count_for(100, 0).should eq(8)
    end

    it "caps at height" do
      config = PrismatIQ::Config.new(threads: 100)
      config.thread_count_for(10, 50).should eq(10)
    end
  end
end
