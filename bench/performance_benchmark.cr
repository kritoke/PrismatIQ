#!/usr/bin/env crystal
require "json"
require "../src/prismatiq"

# Generate test data helpers
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

def generate_gradient(width, height)
  pixels = Array(UInt8).new(width * height * 4)
  height.times do |y|
    width.times do |x|
      r = ((x.to_f / width) * 255).to_u8
      g = ((y.to_f / height) * 255).to_u8
      b = 128_u8
      pixels << r
      pixels << g
      pixels << b
      pixels << 255_u8
    end
  end
  Slice.new(pixels.size) { |idx| pixels[idx] }
end

def generate_random(width, height, seed : UInt64 = 42_u64)
  # Simple seeded random for reproducibility
  random = Random::PCG32.new(seed)
  pixels = Array(UInt8).new(width * height * 4)
  (width * height).times do
    pixels << random.rand(256).to_u8
    pixels << random.rand(256).to_u8
    pixels << random.rand(256).to_u8
    pixels << random.rand(256).to_u8
  end
  Slice.new(pixels.size) { |idx| pixels[idx] }
end

# Benchmark result as a class for type safety
class BenchmarkResult
  getter name : String
  getter iterations : Int32
  getter avg_ms : Float64
  getter min_ms : Float64
  getter max_ms : Float64
  getter std_dev_ms : Float64
  getter ops_sec : Float64

  def initialize(@name, @iterations, @avg_ms, @min_ms, @max_ms, @std_dev_ms, @ops_sec)
  end

  def to_h : Hash(String, JSON::Any)
    {
      "name"       => JSON::Any.new(@name),
      "iterations" => JSON::Any.new(@iterations),
      "avg_ms"     => JSON::Any.new(@avg_ms),
      "min_ms"     => JSON::Any.new(@min_ms),
      "max_ms"     => JSON::Any.new(@max_ms),
      "std_dev_ms" => JSON::Any.new(@std_dev_ms),
      "ops_sec"    => JSON::Any.new(@ops_sec),
    }
  end

  def self.from_h(h : Hash(String, JSON::Any)) : BenchmarkResult
    new(
      h["name"].as_s,
      h["iterations"].as_i,
      h["avg_ms"].as_f,
      h["min_ms"].as_f,
      h["max_ms"].as_f,
      h["std_dev_ms"].as_f,
      h["ops_sec"].as_f
    )
  end
end

# Benchmark runner
class BenchmarkRunner
  @results = [] of BenchmarkResult
  @iterations = 10

  def initialize(@iterations : Int32 = 10)
  end

  def run(name, &block)
    # Warmup run
    yield

    # Timed runs
    times = [] of Float64
    @iterations.times do
      start_time = Time.monotonic
      yield
      end_time = Time.monotonic
      times << (end_time - start_time).total_seconds
    end

    avg_time = times.sum / times.size
    min_time = times.min
    max_time = times.max
    std_dev = Math.sqrt(times.map { |t| (t - avg_time)**2 }.sum / times.size)

    result = BenchmarkResult.new(
      name,
      @iterations,
      (avg_time * 1000).round(3),
      (min_time * 1000).round(3),
      (max_time * 1000).round(3),
      (std_dev * 1000).round(3),
      (1.0 / avg_time).round(1)
    )

    @results << result
    result
  end

  def print_results
    puts "=" * 70
    puts "PrismatIQ Performance Benchmark Results"
    puts "=" * 70
    puts

    @results.each do |r|
      puts r.name
      puts "  Avg:  #{r.avg_ms} ms  (#{r.ops_sec} ops/sec)"
      puts "  Min:  #{r.min_ms} ms"
      puts "  Max:  #{r.max_ms} ms"
      puts "  Std:  #{r.std_dev_ms} ms"
      puts
    end

    puts "-" * 70
    total_ops_sec = @results.map(&.ops_sec).sum
    puts "Total throughput: #{total_ops_sec.round(1)} ops/sec"
    puts "-" * 70
  end

  def save_results(path : String)
    json_results = @results.map(&.to_h)
    File.write(path, JSON.build do |json|
      json.array do
        json_results.each do |h|
          json.object do
            h.each do |k, v|
              json.field k, v
            end
          end
        end
      end
    end)
    puts "\nResults saved to: #{path}"
  end

  def load_baseline(path : String) : Array(BenchmarkResult)?
    return nil unless File.exists?(path)
    JSON.parse(File.read(path)).as_a.map { |item| BenchmarkResult.from_h(item.as_h) }
  end

  def compare_with_baseline(baseline_path : String)
    baseline = load_baseline(baseline_path)
    return unless baseline

    puts "\n" + "=" * 70
    puts "Performance Regression Check"
    puts "=" * 70

    has_regressions = false
    baseline.each do |b|
      current = @results.find { |r| r.name == b.name }
      next unless current

      current_avg = current.avg_ms
      baseline_avg = b.avg_ms
      change_pct = ((current_avg - baseline_avg) / baseline_avg * 100).round(1)

      status = if change_pct > 20
                 has_regressions = true
                 "REGRESSION"
               elsif change_pct < -20
                 "IMPROVEMENT"
               else
                 "OK"
               end

      puts "#{current.name}: #{change_pct > 0 ? "+" : ""}#{change_pct}% (#{status})"
    end

    if has_regressions
      puts "\nWARNING: Performance regressions detected!"
      exit 1
    else
      puts "\nNo performance regressions detected."
    end
  end
end

# Generate test data
puts "Generating test data..."
checker_10 = generate_checkerboard(10, 10)
checker_32 = generate_checkerboard(32, 32)
checker_64 = generate_checkerboard(64, 64)
solid_100 = generate_solid(0, 0, 255, 100, 100)
gradient_100 = generate_gradient(100, 100)
random_100 = generate_random(100, 100)
random_256 = generate_random(256, 256)
random_512 = generate_random(512, 512)

# Run benchmarks
runner = BenchmarkRunner.new(iterations: 20)

puts "\nRunning benchmarks...\n\n"

# Small image benchmarks
runner.run("checker_10x10_single") do
  options = PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 1)
  PrismatIQ.get_palette(checker_10, 10, 10, options)
end

runner.run("checker_32x32_single") do
  options = PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 1)
  PrismatIQ.get_palette(checker_32, 32, 32, options)
end

runner.run("checker_64x64_single") do
  options = PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 1)
  PrismatIQ.get_palette(checker_64, 64, 64, options)
end

# Solid color
runner.run("solid_100x100_single") do
  options = PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 1)
  PrismatIQ.get_palette(solid_100, 100, 100, options)
end

# Gradient
runner.run("gradient_100x100_single") do
  options = PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 1)
  PrismatIQ.get_palette(gradient_100, 100, 100, options)
end

# Random noise
runner.run("random_100x100_single") do
  options = PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 1)
  PrismatIQ.get_palette(random_100, 100, 100, options)
end

runner.run("random_256x256_single") do
  options = PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 1)
  PrismatIQ.get_palette(random_256, 256, 256, options)
end

runner.run("random_512x512_single") do
  options = PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 1)
  PrismatIQ.get_palette(random_512, 512, 512, options)
end

# Multi-threaded benchmarks
runner.run("random_256x256_multi_4") do
  options = PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 4)
  PrismatIQ.get_palette(random_256, 256, 256, options)
end

# Quality variations
runner.run("random_256x256_quality_1") do
  options = PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 1)
  PrismatIQ.get_palette(random_256, 256, 256, options)
end

runner.run("random_256x256_quality_5") do
  options = PrismatIQ::Options.new(color_count: 5, quality: 5, threads: 1)
  PrismatIQ.get_palette(random_256, 256, 256, options)
end

runner.run("random_256x256_quality_10") do
  options = PrismatIQ::Options.new(color_count: 5, quality: 10, threads: 1)
  PrismatIQ.get_palette(random_256, 256, 256, options)
end

# Color count variations
runner.run("random_256x256_colors_3") do
  options = PrismatIQ::Options.new(color_count: 3, quality: 1, threads: 1)
  PrismatIQ.get_palette(random_256, 256, 256, options)
end

runner.run("random_256x256_colors_10") do
  options = PrismatIQ::Options.new(color_count: 10, quality: 1, threads: 1)
  PrismatIQ.get_palette(random_256, 256, 256, options)
end

runner.run("random_256x256_colors_20") do
  options = PrismatIQ::Options.new(color_count: 20, quality: 1, threads: 1)
  PrismatIQ.get_palette(random_256, 256, 256, options)
end

# Stats API
runner.run("random_256x256_stats") do
  options = PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 1)
  PrismatIQ.get_palette_with_stats(random_256, 256, 256, options)
end

# Result type API
runner.run("random_256x256_result") do
  options = PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 1)
  PrismatIQ.get_palette_result(random_256, 256, 256, options)
end

# Edge cases
runner.run("empty_image") do
  empty = Slice(UInt8).new(0)
  options = PrismatIQ::Options.new(color_count: 5)
  PrismatIQ.get_palette(empty, 0, 0, options)
end

runner.run("single_pixel") do
  single = Slice.new(4) { |_i| 255_u8 }
  options = PrismatIQ::Options.new(color_count: 5)
  PrismatIQ.get_palette(single, 1, 1, options)
end

# Print and save results
runner.print_results
runner.save_results("bench/results.json")

# Compare with baseline if exists
baseline_path = "bench/baseline.json"
if File.exists?(baseline_path)
  runner.compare_with_baseline(baseline_path)
else
  puts "\nNote: No baseline found at #{baseline_path}"
  puts "Run with baseline to create: cp bench/results.json bench/baseline.json"
end

puts "\n=== Benchmark Complete ==="
