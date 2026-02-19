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
  # Accept ICO files: if path ends with .ico use the ICO helper which picks the best PNG entry
  if path.ends_with?(".ico")
    # get_palette_from_ico returns an RGB palette; but we want entries + counts, so use CrImage path
    # We'll prefer to decode via our ICO helper and then feed the returned image into get_palette
    entries = PrismatIQ.get_palette_from_ico(path, color_count, quality, threads)
    payload = {
      "colors" => entries.map { |c| c.to_hex },
      "entries" => entries.map { |c| { "hex" => c.to_hex, "count" => 0, "percent" => 0.0 } },
      "total_pixels" => 0
    }
    puts payload.to_json
    exit 0
  else
    img = CrImage.read(path)
  end
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
