#!/usr/bin/env crystal
require "../src/prismatiq"

def generate_checkerboard(width, height)
  pixels = Array(UInt8).new(width * height * 4)
  y = 0
  while y < height
    x = 0
    while x < width
      if (x + y) % 2 == 0
        pixels << 255.to_u8
        pixels << 0.to_u8
        pixels << 0.to_u8
        pixels << 255.to_u8
      else
        pixels << 0.to_u8
        pixels << 255.to_u8
        pixels << 0.to_u8
        pixels << 255.to_u8
      end
      x += 1
    end
    y += 1
  end
  Slice.new(pixels.size) { |idx| pixels[idx] }
end

def generate_solid(r, g, b, width, height)
  pixels = Array(UInt8).new(width * height * 4)
  height.times do
    width.times do
      pixels << r.to_u8
      pixels << g.to_u8
      pixels << b.to_u8
      pixels << 255.to_u8
    end
  end
  Slice.new(pixels.size) { |idx| pixels[idx] }
end

puts "=== PrismatIQ Benchmark Suite ==="
puts

# Generate test data
checker_10 = generate_checkerboard(10, 10)
checker_32 = generate_checkerboard(32, 32)
solid_100 = generate_solid(0, 0, 255, 100, 100)

tests = {
  "checker_10x10" => {checker_10, 10, 10},
  "checker_32x32" => {checker_32, 32, 32},
  "solid_100x100_blue" => {solid_100, 100, 100},
}

tests.each do |name, (pixels, width, height)|
  puts "--- #{name} (#{width}x#{height}) ---"

  # Single-thread
  result = PrismatIQ.get_palette_from_buffer(pixels, width, height, color_count: 5, quality: 1, threads: 1)
  puts "  Single-thread: #{result.map(&.to_hex)}"

  # Multi-thread
  result = PrismatIQ.get_palette_from_buffer(pixels, width, height, color_count: 5, quality: 1, threads: 4)
  puts "  Multi-thread: #{result.map(&.to_hex)}"

  # Stats
  entries, total = PrismatIQ.get_palette_with_stats_from_buffer(pixels, width, height, color_count: 5, quality: 1, threads: 1)
  puts "  Stats: #{entries.size} entries, #{total} pixels"

  # Result type
  result = PrismatIQ.get_palette_or_error(pixels, width, height)
  puts "  Result: ok?=#{result.ok?}"

  # Config
  config = PrismatIQ::Config.new(debug: false, threads: 2)
  result = PrismatIQ.get_palette_from_buffer(pixels, width, height, color_count: 5, quality: 1, config: config)
  puts "  With Config: #{result.map(&.to_hex)}"

  puts
end

puts "=== Edge Cases ==="
puts

# Empty
empty = Slice(UInt8).new(0)
result = PrismatIQ.get_palette_from_buffer(empty, 0, 0, color_count: 5)
puts "Empty: #{result.map(&.to_hex)}"

# Transparent
transparent = Slice.new(4) { |i| i == 3 ? 0.to_u8 : 0.to_u8 }  # All transparent
result = PrismatIQ.get_palette_from_buffer(transparent, 1, 1, color_count: 5)
puts "Transparent: #{result.map(&.to_hex)}"

# Config.thread_count_for
config = PrismatIQ::Config.new(threads: 8)
puts "thread_count_for(100, 0): #{config.thread_count_for(100, 0)}"
puts "thread_count_for(100, 4): #{config.thread_count_for(100, 4)}"
puts "thread_count_for(10, 0): #{config.thread_count_for(10, 0)}"

puts "=== Done ==="
