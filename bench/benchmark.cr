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
  "checker_10x10"      => {checker_10, 10, 10},
  "checker_32x32"      => {checker_32, 32, 32},
  "solid_100x100_blue" => {solid_100, 100, 100},
}

tests.each do |name, (pixels, width, height)|
  puts "--- #{name} (#{width}x#{height}) ---"

  # Single-thread
  options = PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 1)
  result = PrismatIQ.get_palette(pixels, width, height, options)
  puts "  Single-thread: #{result.map(&.to_hex)}"

  # Multi-thread
  options = PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 4)
  result = PrismatIQ.get_palette(pixels, width, height, options)
  puts "  Multi-thread: #{result.map(&.to_hex)}"

  # Stats
  options = PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 1)
  entries, total_pixels = PrismatIQ.get_palette_with_stats(pixels, width, height, options)
  puts "  Stats: #{entries.size} entries, #{total_pixels} pixels"

  # Result type
  result = PrismatIQ.get_palette_or_error(pixels, width, height)
  puts "  Result: ok?=#{result.ok?}"

  # Config
  config = PrismatIQ::Config.new(debug: false, threads: 2)
  options = PrismatIQ::Options.new(color_count: 5, quality: 1)
  result = PrismatIQ.get_palette(pixels, width, height, options, config)
  puts "  With Config: #{result.map(&.to_hex)}"

  puts
end

puts "=== Edge Cases ==="
puts

# Empty
empty = Slice(UInt8).new(0)
options = PrismatIQ::Options.new(color_count: 5)
result = PrismatIQ.get_palette(empty, 0, 0, options)
puts "Empty: #{result.map(&.to_hex)}"

# Transparent
transparent = Slice.new(4) { |i| i == 3 ? 0.to_u8 : 0.to_u8 } # All transparent
options = PrismatIQ::Options.new(color_count: 5)
result = PrismatIQ.get_palette(transparent, 1, 1, options)
puts "Transparent: #{result.map(&.to_hex)}"

# Config.thread_count_for
config = PrismatIQ::Config.new(threads: 8)
puts "thread_count_for(100, 0): #{config.thread_count_for(100, 0)}"
puts "thread_count_for(100, 4): #{config.thread_count_for(100, 4)}"
puts "thread_count_for(10, 0): #{config.thread_count_for(10, 0)}"

puts "=== Done ==="
