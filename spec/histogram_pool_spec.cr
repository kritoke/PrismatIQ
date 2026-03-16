require "./spec_helper"

describe PrismatIQ::Core::HistogramPool do
  describe "#acquire and #release" do
    it "creates new histogram on first acquire for index" do
      pool = PrismatIQ::Core::HistogramPool.new(5)
      histo = pool.acquire(0)

      histo.should be_a(Array(UInt32))
      histo.size.should eq(PrismatIQ::Constants::HISTOGRAM_SIZE)
      histo.all?(&.zero?).should be_true
    end

    it "reuses and clears histogram for same index" do
      pool = PrismatIQ::Core::HistogramPool.new(5)

      histo1 = pool.acquire(0)
      histo1[0] = 42_u32
      pool.release(0)

      histo2 = pool.acquire(0)
      histo2[0].should eq(0_u32)
    end

    it "raises on out of bounds index" do
      pool = PrismatIQ::Core::HistogramPool.new(2)

      expect_raises(ArgumentError, /out of bounds/) do
        pool.acquire(5)
      end
    end

    it "provides separate histograms for different indices" do
      pool = PrismatIQ::Core::HistogramPool.new(3)

      histo0 = pool.acquire(0)
      histo1 = pool.acquire(1)
      histo2 = pool.acquire(2)

      histo0[0] = 10_u32
      histo1[0] = 20_u32
      histo2[0] = 30_u32

      histo0[0].should eq(10_u32)
      histo1[0].should eq(20_u32)
      histo2[0].should eq(30_u32)
    end
  end

  describe "#size" do
    it "returns count of used histograms" do
      pool = PrismatIQ::Core::HistogramPool.new(5)
      pool.size.should eq(0)

      pool.acquire(0)
      pool.size.should eq(1)

      pool.acquire(1)
      pool.size.should eq(2)

      pool.release(0)
      pool.size.should eq(1)
    end
  end

  describe "#clear" do
    it "clears all used flags and zeros histograms" do
      pool = PrismatIQ::Core::HistogramPool.new(3)

      histo = pool.acquire(0)
      histo[0] = 99_u32

      pool.clear

      pool.size.should eq(0)
      histo[0].should eq(0_u32)
    end
  end

  describe "#stats" do
    it "returns correct statistics" do
      pool = PrismatIQ::Core::HistogramPool.new(10)

      stats = pool.stats
      stats[:pool_size].should eq(0)
      stats[:total_capacity].should eq(10 * PrismatIQ::Constants::HISTOGRAM_SIZE)

      pool.acquire(0)
      pool.acquire(1)

      stats = pool.stats
      stats[:pool_size].should eq(2)
    end
  end

  describe "thread safety" do
    it "handles concurrent acquire/release safely for different indices" do
      pool = PrismatIQ::Core::HistogramPool.new(20)
      channel = Channel(Bool).new(100)

      100.times do |i|
        spawn do
          idx = i % 20
          pool.acquire(idx)
          sleep 0.001.milliseconds
          pool.release(idx)
          channel.send(true)
        end
      end

      100.times { channel.receive }
    end
  end
end

describe PrismatIQ::Core::AdaptiveChunkSizer do
  describe ".should_use_parallel?" do
    it "returns false for small images" do
      PrismatIQ::Core::AdaptiveChunkSizer.should_use_parallel?(50_000).should be_false
      PrismatIQ::Core::AdaptiveChunkSizer.should_use_parallel?(99_999).should be_false
    end

    it "returns true for large images" do
      PrismatIQ::Core::AdaptiveChunkSizer.should_use_parallel?(100_001).should be_true
      PrismatIQ::Core::AdaptiveChunkSizer.should_use_parallel?(1_000_000).should be_true
    end
  end

  describe ".calculate" do
    it "returns image size for small images" do
      size = PrismatIQ::Core::AdaptiveChunkSizer.calculate(50_000, 8)
      size.should eq(50_000)
    end

    it "returns clamped chunk size for medium images" do
      size = PrismatIQ::Core::AdaptiveChunkSizer.calculate(500_000, 4)
      size.should be >= 10_000
      size.should be <= 100_000
    end

    it "returns clamped chunk size for large images" do
      size = PrismatIQ::Core::AdaptiveChunkSizer.calculate(10_000_000, 8)
      size.should be >= 50_000
      size.should be <= 500_000
    end
  end

  describe ".optimal_thread_count" do
    it "returns 1 for small images" do
      count = PrismatIQ::Core::AdaptiveChunkSizer.optimal_thread_count(50_000, 16)
      count.should eq(1)
    end

    it "returns 2 for medium images" do
      count = PrismatIQ::Core::AdaptiveChunkSizer.optimal_thread_count(300_000, 16)
      count.should eq(2)
    end

    it "returns 4 for larger images" do
      count = PrismatIQ::Core::AdaptiveChunkSizer.optimal_thread_count(1_500_000, 16)
      count.should eq(4)
    end

    it "respects max_threads parameter" do
      count = PrismatIQ::Core::AdaptiveChunkSizer.optimal_thread_count(20_000_000, 4)
      count.should eq(4)
    end
  end
end
