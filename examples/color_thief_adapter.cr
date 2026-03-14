# Simple CLI adapter demonstrating how to call PrismatIQ and
# emit a ColorThief‑compatible JSON payload from a local image.
#
# Usage:
#   crystal run examples/color_thief_adapter.cr -- path/to/image.jpg [count] [quality] [threads]

require "../src/prismatiq"
require "json"

if ARGV.empty?
  STDERR.puts "usage: crystal run examples/color_thief_adapter.cr -- path/to/image.jpg [count] [quality] [threads]"
  exit 1
end

path = ARGV[0]
color_count = (ARGV[1] || "5").to_i
quality = (ARGV[2] || "10").to_i
threads = (ARGV[3] || "0").to_i

# Create Options struct with the new API pattern
options = PrismatIQ::Options.new(
  color_count: color_count,
  quality: quality,
  threads: threads
)

begin
  # Accept ICO files: if path ends with .ico use the ICO helper which picks the best PNG entry
  if path.ends_with?(".ico")
    # get_palette_from_ico returns an RGB palette; but we want entries + counts, so use CrImage path
    # We'll prefer to decode via our ICO helper and then feed the returned image into get_palette
    entries = PrismatIQ.get_palette_from_ico(path, options)
    payload = {
      "colors"       => entries.map(&.to_hex),
      "entries"      => entries.map { |color| {"hex" => color.to_hex, "count" => 0, "percent" => 0.0} },
      "total_pixels" => 0,
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
  # Using the new Options-based API (get_palette_with_stats)
  rgba_image = CrImage::Pipeline.new(img).result
  width = rgba_image.bounds.width.to_i32
  height = rgba_image.bounds.height.to_i32
  src = rgba_image.pix
  pixels = Slice(UInt8).new(src.size) { |i| src[i] }
  entries, total = PrismatIQ.get_palette_with_stats(pixels, width, height, options)

entries_payload = entries.map do |e|
  {
    "hex"     => e.rgb.to_hex,
    "count"   => e.count,
    "percent" => e.percent,
  }
end

payload = {
  "colors"       => entries.map(&.rgb.to_hex),
  "entries"      => entries_payload,
  "total_pixels" => total,
}

puts payload.to_json
