require "./spec_helper"

describe PrismatIQ::Core::HistogramPool do
  describe "#acquire and #release" do
    it "creates new histogram when pool is empty" do
      pool = PrismatIQ::Core::HistogramPool.new(5)
      histo = pool.acquire
      
      histo.should be_a(Array(UInt32))
      histo.size.should eq(PrismatIQ::Constants::HISTOGRAM_SIZE)
      histo.all?(&.zero?).should be_true
    end

    it "reuses histogram from pool" do
      pool = PrismatIQ::Core::HistogramPool.new(5)
      
      histo1 = pool.acquire
      histo1[0] = 42_u32
      pool.release(histo1)
      
      histo2 = pool.acquire
      histo2[0].should eq(0_u32) # Should be cleared
      pool.size.should eq(0) # Pool should be empty after acquire
    end

    it "does not exceed max pool size" do
      pool = PrismatIQ::Core::HistogramPool.new(2)
      
      histo1 = pool.acquire
      histo2 = pool.acquire
      histo3 = pool.acquire
      
      pool.release(histo1)
      pool.release(histo2)
      pool.release(histo3)
      
      pool.size.should eq(2) # Should not exceed max size
    end
  end

  describe "#stats" do
    it "returns correct statistics" do
      pool = PrismatIQ::Core::HistogramPool.new(10)
      
      stats = pool.stats
      stats[:pool_size].should eq(0)
      stats[:max_size].should eq(10)
      
      histo = pool.acquire
      pool.release(histo)
      
      stats = pool.stats
      stats[:pool_size].should eq(1)
      stats[:total_capacity].should eq(PrismatIQ::Constants::HISTOGRAM_SIZE)
    end
  end

  describe "thread safety" do
    it "handles concurrent acquire/release safely" do
      pool = PrismatIQ::Core::HistogramPool.new(20)
      channel = Channel(Bool).new(100)
      
      100.times do
        spawn do
          histo = pool.acquire
          sleep 0.001.milliseconds
          pool.release(histo)
          channel.send(true)
        end
      end
      
      100.times { channel.receive }
      pool.size.should be > 0
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
