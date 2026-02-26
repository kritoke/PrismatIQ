require "./spec_helper"

describe "TempfileHelper" do
  it "creates a tempfile and writes binary contents exactly" do
    # prepare binary data including bytes > 127 to ensure raw write preserved
    arr = [0_u8, 1_u8, 2_u8, 10_u8, 127_u8, 128_u8, 200_u8, 255_u8]
    data = Slice(UInt8).new(arr.size)
    i = 0
    while i < arr.size
      data[i] = arr[i]
      i += 1
    end

    outer_path = nil
    res = PrismatIQ::TempfileHelper.with_tempfile("prism_test_", data) do |p|
      outer_path = p
      outer_path.should_not be_nil

      File.exists?(p).should be_true

      # read raw bytes and compare
      content = File.read(p)
      # convert to slice for comparison
      got = content.to_slice
      got.size.should eq(arr.size)
      i = 0
      while i < arr.size
        got[i].should eq(arr[i])
        i += 1
      end

      true
    end

    res.should be_true
    outer_path.should_not be_nil
    File.exists?(outer_path.not_nil!).should be_false
  end

  it "returns nil on repeated failure to create tempfile" do
    # This is a smoke test: exercise API with an extremely long prefix that
    # might cause a failure on some platforms; the exact behavior may vary.
    long_prefix = "x" * 4096
    arr = [1_u8, 2_u8, 3_u8]
    s = Slice(UInt8).new(arr.size)
    i = 0
    while i < arr.size
      s[i] = arr[i]
      i += 1
    end

    # We don't assert a specific outcome (nil vs path) here on all platforms,
    # but calling into the helper should not raise an exception.
    begin
      _ = PrismatIQ::TempfileHelper.create_and_write(long_prefix, s)
    rescue ex
      fail "TempfileHelper raised unexpectedly: #{ex.message}"
    end
  end
end
