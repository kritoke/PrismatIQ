#!/usr/bin/env crystal
# Performance Benchmark Suite for PrismatIQ
# Run with: crystal run --release bench/performance.cr

require "benchmark"
require "../src/prismatiq"

module PerformanceBench
  def self.generate_gradient_image(width : Int32, height : Int32) : Slice(UInt8)
    pixels = Pointer(UInt8).malloc(width * height * 4)
    y = 0
    while y < height
      x = 0
      while x < width
        idx = (y * width + x) * 4
        pixels[idx] = ((x.to_f / width) * 255).to_u8
        pixels[idx + 1] = ((y.to_f / height) * 255).to_u8
        pixels[idx + 2] = 128_u8
        pixels[idx + 3] = 255_u8
        x += 1
      end
      y += 1
    end
    Slice.new(pixels, width * height * 4)
  end

  def self.generate_random_image(width : Int32, height : Int32) : Slice(UInt8)
    pixels = Pointer(UInt8).malloc(width * height * 4)
    rand = Random.new(42)
    (width * height).times do |i|
      idx = i * 4
      pixels[idx] = rand.next_u8
      pixels[idx + 1] = rand.next_u8
      pixels[idx + 2] = rand.next_u8
      pixels[idx + 3] = 255_u8
    end
    Slice.new(pixels, width * height * 4)
  end

  struct Result
    getter name : String
    getter size : String
    getter time_ms : Float64
    getter iterations : Int32

    def initialize(@name, @size, @time_ms, @iterations)
    end

    def avg_ms : Float64
      @time_ms / @iterations
    end

    def to_s : String
      "#{@name} (#{@size}): avg #{avg_ms.round(2)}ms (#{@iterations} iters)"
    end
  end

  class Suite
    @results = [] of Result

    def benchmark(name : String, width : Int32, height : Int32, options : PrismatIQ::Options, iterations : Int32 = 5)
      pixels = PerformanceBench.generate_gradient_image(width, height)

      total_time = Benchmark.realtime do
        iterations.times do
          PrismatIQ.get_palette(pixels, width, height, options)
        end
      end

      result = Result.new(name, "#{width}x#{height}", total_time.total_milliseconds, iterations)
      @results << result
      result
    end

    def benchmark_multithread(name : String, width : Int32, height : Int32, color_count : Int32 = 5, iterations : Int32 = 3)
      pixels = PerformanceBench.generate_gradient_image(width, height)

      [1, 2, 4, 8].each do |threads|
        options = PrismatIQ::Options.new(color_count: color_count, quality: 1, threads: threads)
        total_time = Benchmark.realtime do
          iterations.times do
            PrismatIQ.get_palette(pixels, width, height, options)
          end
        end
        result = Result.new("#{name} (#{threads}T)", "#{width}x#{height}", total_time.total_milliseconds, iterations)
        @results << result
        puts "  #{result}"
      end
    end

    def print_summary
      puts
      puts "=" * 60
      puts "PERFORMANCE BENCHMARK SUMMARY"
      puts "=" * 60
      puts
      printf "%-30s %12s %12s\n", "Test", "Size", "Avg (ms)"
      puts "-" * 60
      @results.sort_by(&.avg_ms).each do |result|
        printf "%-30s %12s %12.2f\n", result.name, result.size, result.avg_ms
      end
      puts
      puts "=" * 60
    end

    def check_regression(baseline : Hash(String, Float64), tolerance_percent : Float64 = 20.0)
      puts
      puts "REGRESSION CHECK (tolerance: #{tolerance_percent}%)"
      puts "-" * 60

      regressions = [] of {String, Float64, Float64, Float64}

      @results.each do |result|
        key = "#{result.name}|#{result.size}"
        if baseline_avg = baseline[key]?
          change_percent = ((r.avg_ms - baseline_avg) / baseline_avg) * 100
          if change_percent > tolerance_percent
            regressions << {key, baseline_avg, r.avg_ms, change_percent}
          end
        end
      end

      if regressions.empty?
        puts "✓ No regressions detected"
      else
        puts "⚠ REGRESSIONS DETECTED:"
        regressions.each do |key, baseline_avg, current_avg, change_percent|
          puts "  #{key}: #{baseline_avg.round(2)}ms → #{current_avg.round(2)}ms (+#{change_percent.round(1)}%)"
        end
      end
      regressions.empty?
    end
  end
end

suite = PerformanceBench::Suite.new

puts "PrismatIQ Performance Benchmark Suite"
puts "=" * 60
puts

puts "--- Small Images ---"
suite.benchmark("small_gradient", 64, 64, PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 1), 50)
suite.benchmark("small_gradient", 64, 64, PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 4), 50)

puts "--- Medium Images ---"
suite.benchmark("medium_gradient", 512, 512, PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 1), 10)
suite.benchmark("medium_gradient", 512, 512, PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 4), 10)

puts "--- HD Images (720p) ---"
suite.benchmark("hd_gradient", 1280, 720, PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 1), 5)
suite.benchmark("hd_gradient", 1280, 720, PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 4), 5)

puts "--- Full HD Images (1080p) ---"
suite.benchmark("fhd_gradient", 1920, 1080, PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 1), 3)
suite.benchmark("fhd_gradient", 1920, 1080, PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 4), 3)

puts "--- 4K Images (2160p) ---"
suite.benchmark("4k_gradient", 3840, 2160, PrismatIQ::Options.new(color_count: 5, quality: 1, threads: 4), 2)

puts
puts "--- Threading Scalability (1080p) ---"
suite.benchmark_multithread("scalability", 1920, 1080, 5, 3)

puts
puts "--- Color Count Impact (1080p) ---"
[3, 5, 8, 10, 16].each do |count|
  suite.benchmark("colors_#{count}", 1920, 1080, PrismatIQ::Options.new(color_count: count, quality: 1, threads: 4), 3)
end

puts
puts "--- Quality Impact (1080p) ---"
[1, 5, 10].each do |quality|
  suite.benchmark("quality_#{quality}", 1920, 1080, PrismatIQ::Options.new(color_count: 5, quality: quality, threads: 4), 3)
end

suite.print_summary

baseline = {
  "small_gradient (64x64)"    => 0.5,
  "medium_gradient (512x512)" => 5.0,
  "hd_gradient (1280x720)"    => 15.0,
  "fhd_gradient (1920x1080)"  => 35.0,
  "4k_gradient (3840x2160)"   => 150.0,
}

suite.check_regression(baseline, 50.0)
