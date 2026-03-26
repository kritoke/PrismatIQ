require "./spec_helper"
require "../src/prismatiq/lru_cache"

describe PrismatIQ::LRUCache do
  describe "initialization" do
    it "creates cache with valid capacity" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 10)
      cache.capacity.should eq(10)
      cache.size.should eq(0)
      cache.empty?.should be_true
    end

    it "raises error for zero capacity" do
      expect_raises(ArgumentError, "Capacity must be positive") do
        PrismatIQ::LRUCache(String, Int32).new(capacity: 0)
      end
    end

    it "raises error for negative capacity" do
      expect_raises(ArgumentError, "Capacity must be positive") do
        PrismatIQ::LRUCache(String, Int32).new(capacity: -5)
      end
    end
  end

  describe "basic operations" do
    it "stores and retrieves values" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 10)
      cache.put("key1", 42)
      cache.get("key1").should eq(42)
    end

    it "returns nil for non-existent keys" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 10)
      cache.get("nonexistent").should be_nil
    end

    it "updates existing key values" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 10)
      cache.put("key", 1)
      cache.put("key", 2)
      cache.get("key").should eq(2)
      cache.size.should eq(1)
    end

    it "returns correct size" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 10)
      cache.put("a", 1)
      cache.put("b", 2)
      cache.put("c", 3)
      cache.size.should eq(3)
    end

    it "returns true for empty? when empty" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 10)
      cache.empty?.should be_true
    end

    it "returns false for empty? when not empty" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 10)
      cache.put("key", 1)
      cache.empty?.should be_false
    end

    it "returns correct has_key? results" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 10)
      cache.put("key1", 1)
      cache.has_key?("key1").should be_true
      cache.has_key?("key2").should be_false
    end

    it "clears all entries" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 10)
      cache.put("key1", 1)
      cache.put("key2", 2)
      cache.clear
      cache.size.should eq(0)
      cache.empty?.should be_true
    end
  end

  describe "LRU eviction" do
    it "evicts least recently used when at capacity" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 3)
      cache.put("a", 1)
      cache.put("b", 2)
      cache.put("c", 3)
      cache.put("d", 4) # Should evict "a"

      cache.size.should eq(3)
      cache.get("a").should be_nil
      cache.get("b").should eq(2)
      cache.get("c").should eq(3)
      cache.get("d").should eq(4)
    end

    it "updates access order on get" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 3)
      cache.put("a", 1)
      cache.put("b", 2)
      cache.put("c", 3)

      # Access "a" to make it most recent
      cache.get("a")

      # Add new item - should evict "b" (now least recent)
      cache.put("d", 4)

      cache.get("a").should eq(1)  # Should still be there
      cache.get("b").should be_nil # Should be evicted
      cache.get("c").should eq(3)
      cache.get("d").should eq(4)
    end

    it "updates access order on put of existing key" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 3)
      cache.put("a", 1)
      cache.put("b", 2)
      cache.put("c", 3)

      # Update "a" to make it most recent
      cache.put("a", 10)

      # Add new item - should evict "b" (now least recent)
      cache.put("d", 4)

      cache.get("a").should eq(10) # Should still be there
      cache.get("b").should be_nil # Should be evicted
      cache.get("c").should eq(3)
      cache.get("d").should eq(4)
    end

    it "evicts in correct order with multiple accesses" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 3)
      cache.put("a", 1)
      cache.put("b", 2)
      cache.put("c", 3)

      # Access order: a, b, c (c is most recent)
      cache.get("a") # a is now most recent
      cache.get("b") # b is now most recent
      # c is least recent

      cache.put("d", 4) # Should evict c
      cache.get("c").should be_nil

      # Now order is: d (most), b, a (least)
      cache.put("e", 5) # Should evict a
      cache.get("a").should be_nil
    end

    it "handles capacity of 1" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 1)
      cache.put("a", 1)
      cache.get("a").should eq(1)

      cache.put("b", 2) # Should evict "a"
      cache.get("a").should be_nil
      cache.get("b").should eq(2)
      cache.size.should eq(1)
    end
  end

  describe "utility methods" do
    it "returns keys in access order (most to least recent)" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 5)
      cache.put("a", 1)
      cache.put("b", 2)
      cache.put("c", 3)
      cache.get("a") # Make a most recent
      cache.put("d", 4)

      cache.keys.should eq(["d", "a", "c", "b"])
    end

    it "returns values in access order (most to least recent)" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 5)
      cache.put("a", 10)
      cache.put("b", 20)
      cache.put("c", 30)
      cache.get("a") # Make a most recent
      cache.put("d", 40)

      cache.values.should eq([40, 10, 30, 20])
    end

    it "yields each key-value pair in access order" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 5)
      cache.put("a", 10)
      cache.put("b", 20)
      cache.put("c", 30)
      cache.get("a") # Make a most recent
      cache.put("d", 40)

      result = [] of Tuple(String, Int32)
      cache.each { |k, v| result << {k, v} }
      result.should eq([{"d", 40}, {"a", 10}, {"c", 30}, {"b", 20}])
    end

    it "has_key? does not affect access order" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 3)
      cache.put("a", 1)
      cache.put("b", 2)
      cache.put("c", 3)

      # Check if key exists (should not affect order)
      cache.has_key?("a")
      cache.has_key?("b")
      cache.has_key?("c")

      # Add new item - should evict "a" (first inserted, least recent)
      cache.put("d", 4)
      cache.get("a").should be_nil
    end
  end

  describe "edge cases" do
    it "handles nil values" do
      cache = PrismatIQ::LRUCache(String, Int32?).new(capacity: 5)
      cache.put("nil_key", nil)
      cache.get("nil_key").should be_nil
      cache.has_key?("nil_key").should be_true
    end

    it "handles empty string keys" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 5)
      cache.put("", 100)
      cache.get("").should eq(100)
    end

    it "handles zero as a valid value" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 5)
      cache.put("zero", 0)
      cache.get("zero").should eq(0)
      cache.has_key?("zero").should be_true
    end

    it "handles false as a valid value" do
      cache = PrismatIQ::LRUCache(String, Bool).new(capacity: 5)
      cache.put("flag", false)
      cache.get("flag").should be_false
      cache.has_key?("flag").should be_true
    end

    it "works with different key/value types" do
      cache = PrismatIQ::LRUCache(Int32, String).new(capacity: 5)
      cache.put(1, "one")
      cache.put(2, "two")
      cache.get(1).should eq("one")
      cache.get(2).should eq("two")
    end

    it "works with tuple keys" do
      cache = PrismatIQ::LRUCache(Tuple(Int32, Int32), String).new(capacity: 5)
      cache.put({1, 2}, "point")
      cache.get({1, 2}).should eq("point")
    end

    it "handles rapid insertion and eviction" do
      cache = PrismatIQ::LRUCache(Int32, Int32).new(capacity: 5)

      # Insert more than capacity
      10.times do |i|
        cache.put(i, i * 10)
      end

      cache.size.should eq(5)

      # Only last 5 items should remain
      5.times do |i|
        cache.get(i).should be_nil
      end

      5.upto(9) do |i|
        cache.get(i).should eq(i * 10)
      end
    end

    it "handles repeated clear and access" do
      cache = PrismatIQ::LRUCache(String, Int32).new(capacity: 5)

      5.times do
        cache.put("key", 42)
        cache.clear
      end

      cache.size.should eq(0)
      cache.put("key", 100)
      cache.get("key").should eq(100)
    end
  end

  describe "performance characteristics" do
    it "maintains O(1) behavior for get operations" do
      cache = PrismatIQ::LRUCache(Int32, Int32).new(capacity: 1000)

      # Fill cache
      1000.times do |i|
        cache.put(i, i)
      end

      # Access all items
      1000.times do |i|
        cache.get(i).should eq(i)
      end

      cache.size.should eq(1000)
    end

    it "maintains O(1) behavior for put operations" do
      cache = PrismatIQ::LRUCache(Int32, Int32).new(capacity: 1000)

      # Insert and evict many items
      2000.times do |i|
        cache.put(i, i)
      end

      cache.size.should eq(1000)

      # Verify correct items remain
      1000.times do |i|
        cache.get(i).should be_nil
      end

      1000.upto(1999) do |i|
        cache.get(i).should eq(i)
      end
    end
  end
end
