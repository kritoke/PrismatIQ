# Simple CLI adapter demonstrating how to call PrismatIQ and
# emit a ColorThief‑compatible JSON payload from a local image.
#
# Usage:
#   crystal run examples/color_thief_adapter.cr -- path/to/image.jpg [count] [quality] [threads]


require "./src/prismatiq"
require "json"

if ARGV.empty?
  STDERR.puts "usage: crystal run examples/color_thief_adapter.cr -- path/to/image.jpg [count] [quality] [threads]"
  exit 1
end

path = ARGV[0]
color_count = (ARGV[1] || "5").to_i
quality = (ARGV[2] || "10").to_i
threads = (ARGV[3] || "0").to_i

begin
  img = CrImage.read(path)
rescue ex : Exception
  STDERR.puts "failed to read image: #{ex.message}"
  exit 2
end

# Use the buffer-based API which returns counts and percentages.
# This example emits a small JSON object intended to match ColorThief-like
# consumers: a `colors` array (hex strings, dominant first) plus richer
# `entries` with counts and percentages for integration or debugging.
entries, total = PrismatIQ.get_palette_with_stats_from_buffer(img.pix, img.width, img.height, color_count, quality, threads)

entries_payload = entries.map do |e|
  {
    "hex" => e.rgb.to_hex,
    "count" => e.count,
    "percent" => e.percent
  }
end

payload = {
  "colors" => entries.map { |e| e.rgb.to_hex },
  "entries" => entries_payload,
  "total_pixels" => total
}

puts payload.to_json
