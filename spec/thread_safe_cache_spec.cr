require "./spec_helper"
require "../src/prismatiq/thread_safe_cache"

describe PrismatIQ::ThreadSafeCache do
  describe "basic operations" do
    it "stores and retrieves values" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new
      cache.get_or_compute("key1") { 42 }
      cache["key1"].should eq(42)
    end

    it "computes values lazily" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new
      computed = false

      result = cache.get_or_compute("key") do
        computed = true
        100
      end

      result.should eq(100)
      computed.should be_true
    end

    it "returns cached value on subsequent calls" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new
      call_count = 0

      cache.get_or_compute("key") { call_count += 1; 42 }
      cache.get_or_compute("key") { call_count += 1; 42 }
      cache.get_or_compute("key") { call_count += 1; 42 }

      call_count.should eq(1)
    end

    it "returns correct size" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new
      cache.get_or_compute("a") { 1 }
      cache.get_or_compute("b") { 2 }
      cache.get_or_compute("c") { 3 }
      cache.size.should eq(3)
    end

    it "returns true for empty? when empty" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new
      cache.empty?.should be_true
    end

    it "returns false for empty? when not empty" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new
      cache.get_or_compute("key") { 1 }
      cache.empty?.should be_false
    end

    it "returns correct has_key? results" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new
      cache.get_or_compute("key1") { 1 }
      cache.has_key?("key1").should be_true
      cache.has_key?("key2").should be_false
    end

    it "clears all entries" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new
      cache.get_or_compute("key1") { 1 }
      cache.get_or_compute("key2") { 2 }
      cache.clear
      cache.size.should eq(0)
      cache.empty?.should be_true
    end

    it "works with different key/value types" do
      cache = PrismatIQ::ThreadSafeCache(Int32, String).new
      cache.get_or_compute(1) { "one" }
      cache.get_or_compute(2) { "two" }
      cache[1].should eq("one")
      cache[2].should eq("two")
    end
  end

  describe "concurrent access" do
    it "handles concurrent reads without deadlock" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new

      # Pre-populate cache
      100.times do |i|
        cache.get_or_compute("key_#{i}") { i * 10 }
      end

      # Spawn multiple fibers that read concurrently
      results = [] of Int32
      mutex = Mutex.new

      10.times do
        spawn do
          100.times do |i|
            value = cache["key_#{i % 100}"]
            if value
              mutex.synchronize { results << value }
            end
          end
        end
      end

      # Wait for all fibers to complete
      ::sleep(500.milliseconds)

      # All reads should have completed successfully
      results.size.should eq(1000)
      results.all? { |v| v >= 0 && v < 1000 }.should be_true
    end

    it "handles concurrent writes without race conditions" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new

      results = [] of Int32
      mutex = Mutex.new

      # Multiple fibers writing to different keys concurrently
      10.times do |i|
        spawn do
          10.times do |j|
            key = "key_#{i * 10 + j}"
            value = cache.get_or_compute(key) { i * 10 + j }
            mutex.synchronize { results << value }
          end
        end
      end

      ::sleep(500.milliseconds)

      # All writes should have completed
      results.size.should eq(100)
      cache.size.should eq(100)
    end

    it "only computes once per key with concurrent access (double-checked locking)" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new
      compute_count = 0
      mutex = Mutex.new
      results = [] of Int32

      # Multiple fibers trying to compute the same key concurrently
      20.times do
        spawn do
          value = cache.get_or_compute("shared_key") do
            mutex.synchronize { compute_count += 1 }
            # Small delay to increase chance of concurrent computation attempts
            ::sleep(10.milliseconds)
            42
          end
          mutex.synchronize { results << value }
        end
      end

      ::sleep(1.second)

      # Only ONE computation should have occurred
      compute_count.should eq(1)

      # All results should be 42
      results.all? { |v| v == 42 }.should be_true
    end

    it "handles concurrent reads and writes to different keys" do
      cache = PrismatIQ::ThreadSafeCache(Int32, String).new
      results = [] of String
      mutex = Mutex.new

      # Reader fibers
      5.times do
        spawn do
          50.times do |i|
            value = cache.get_or_compute(i) { "value_#{i}" }
            mutex.synchronize { results << value }
          end
        end
      end

      # Writer fibers (some keys overlap with readers)
      5.times do
        spawn do
          50.times do |i|
            value = cache.get_or_compute(i + 25) { "new_value_#{i + 25}" }
            mutex.synchronize { results << value }
          end
        end
      end

      ::sleep(500.milliseconds)

      # All operations should have completed
      results.size.should eq(500)

      # Cache should have all 75 unique keys (0-74)
      cache.size.should eq(75)
    end

    it "handles concurrent clear operations" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new

      # Pre-populate cache
      50.times do |i|
        cache.get_or_compute("key_#{i}") { i }
      end

      # Clear concurrently with reads/writes
      spawn do
        10.times do
          cache.clear
          ::sleep(10.milliseconds)
        end
      end

      10.times do
        spawn do
          10.times do |i|
            cache.get_or_compute("key_#{i}") { i }
          end
        end
      end

      ::sleep(500.milliseconds)

      # Should have consistent state - cache should have some entries
      # (exact count depends on timing, but should be between 0 and 50)
      cache.size.should be <= 50
    end

    it "handles high contention with many concurrent fibers" do
      cache = PrismatIQ::ThreadSafeCache(String, Int64).new
      compute_count = 0_i64
      mutex = Mutex.new

      fiber_count = 50
      iterations_per_fiber = 20
      key_count = 10

      fiber_count.times do
        spawn do
          iterations_per_fiber.times do |i|
            key = "key_#{i % key_count}"
            cache.get_or_compute(key) do
              mutex.synchronize { compute_count += 1 }
              value = compute_count
              value
            end
          end
        end
      end

      ::sleep(1.second)

      compute_count.should eq(key_count)
      cache.size.should eq(key_count)
    end

    it "handles 100 fibers accessing same cache concurrently" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new
      compute_count = 0
      mutex = Mutex.new
      results = Channel(Int32).new(100)

      100.times do |_|
        spawn do
          key = "shared_key"
          value = cache.get_or_compute(key) do
            mutex.synchronize { compute_count += 1 }
            ::sleep(5.milliseconds)
            42
          end
          results.send(value)
        end
      end

      received = [] of Int32
      100.times { received << results.receive }

      compute_count.should eq(1)
      received.all? { |v| v == 42 }.should be_true
      cache.size.should eq(1)
    end

    it "handles 100 fibers with mixed read/write operations" do
      cache = PrismatIQ::ThreadSafeCache(Int32, Int32).new
      errors = Channel(String?).new(100)

      100.times do |fiber_idx|
        spawn do
          begin
            10.times do |op|
              key = fiber_idx * 10 + op
              if op % 2 == 0
                cache.get_or_compute(key) { key * 2 }
              else
                cache[key] = key * 3
              end
            end
            errors.send(nil)
          rescue ex : Exception
            errors.send(ex.message)
          end
        end
      end

      error_messages = [] of String?
      100.times { error_messages << errors.receive }

      error_messages.compact.size.should eq(0)
      cache.size.should be > 0
    end

    it "works with complex value types under concurrent access" do
      cache = PrismatIQ::ThreadSafeCache(String, Array(Int32)).new

      results = [] of Array(Int32)
      mutex = Mutex.new

      10.times do
        spawn do
          10.times do |i|
            value = cache.get_or_compute("arr_#{i % 5}") do
              # Return a new array each time, but cache ensures only one is created
              Array(Int32).new(i) { |j| j * 2 }
            end
            mutex.synchronize { results << value }
          end
        end
      end

      ::sleep(500.milliseconds)

      # All results should be valid arrays
      results.each do |arr|
        arr.should be_a(Array(Int32))
      end

      # Cache should have exactly 5 unique arrays
      cache.size.should eq(5)
    end
  end

  describe "direct bracket access" do
    it "returns nil for non-existent key with []" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new
      cache["nonexistent"].should be_nil
    end

    it "returns value for existing key with []" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new
      cache.get_or_compute("key") { 42 }
      cache["key"].should eq(42)
    end

    it "sets value with []=" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new
      cache["key"] = 100
      cache["key"].should eq(100)
    end

    it "overwrites existing value with []=" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new
      cache.get_or_compute("key") { 50 }
      cache["key"] = 100
      cache["key"].should eq(100)
    end
  end

  describe "mixed access patterns" do
    it "allows mixing get_or_compute and direct access" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new

      # Use get_or_compute first
      cache.get_or_compute("a") { 1 }

      # Use direct access
      cache["b"] = 2

      # Both should work
      cache["a"].should eq(1)
      cache["b"].should eq(2)
      cache.size.should eq(2)
    end

    it "get_or_compute doesn't overwrite direct assignments" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new

      # Set directly first
      cache["key"] = 100

      # get_or_compute should return cached value, not recompute
      result = cache.get_or_compute("key") { 999 }
      result.should eq(100)
      cache["key"].should eq(100)
    end
  end

  describe "edge cases" do
    it "handles nil values correctly" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32?).new
      cache.get_or_compute("nil_key") { nil }
      cache["nil_key"].should be_nil
    end

    it "handles empty string keys" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new
      cache.get_or_compute("") { 100 }
      cache[""].should eq(100)
    end

    it "handles empty block result" do
      cache = PrismatIQ::ThreadSafeCache(String, Array(Int32)).new
      result = cache.get_or_compute("empty") { [] of Int32 }
      result.should eq([] of Int32)
    end

    it "handles repeated clear and access" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new

      5.times do
        cache.get_or_compute("key") { 42 }
        cache.clear
      end

      cache.size.should eq(0)
      cache.get_or_compute("key") { 100 }
      cache.size.should eq(1)
      cache["key"].should eq(100)
    end

    it "handles symbol keys" do
      cache = PrismatIQ::ThreadSafeCache(Symbol, String).new
      cache.get_or_compute(:foo) { "bar" }
      cache[:foo].should eq("bar")
      cache.has_key?(:foo).should be_true
    end

    it "handles tuple keys" do
      cache = PrismatIQ::ThreadSafeCache(Tuple(Int32, Int32), String).new
      cache.get_or_compute({1, 2}) { "point" }
      cache[{1, 2}].should eq("point")
    end

    it "handles zero as a valid value" do
      cache = PrismatIQ::ThreadSafeCache(String, Int32).new
      cache.get_or_compute("zero") { 0 }
      cache["zero"].should eq(0)
      cache.has_key?("zero").should be_true
    end

    it "handles false as a valid value" do
      cache = PrismatIQ::ThreadSafeCache(String, Bool).new
      cache.get_or_compute("flag") { false }
      cache["flag"].should be_false
    end
  end
end
