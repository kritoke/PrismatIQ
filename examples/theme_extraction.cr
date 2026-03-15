require "../src/prismatiq"

puts "=== PrismatIQ Theme Extraction Examples ==="
puts

puts "1. Extract theme from a local file:"
result = PrismatIQ.extract_theme("spec/fixtures/ico/golden_png_32.png")
if result
  puts "   Background: #{result.bg}"
  puts "   Light theme text: #{result.text["light"]}"
  puts "   Dark theme text: #{result.text["dark"]}"
  puts "   JSON: #{result.to_json}"
end
puts

puts "2. Extract theme from an ICO file:"
result = PrismatIQ.extract_theme("spec/fixtures/ico/png_icon_32x32.ico")
if result
  puts "   Background: #{result.bg}"
  puts "   Text colors: #{result.text}"
end
puts

puts "3. Use skip_if_configured option:"
options = PrismatIQ::ThemeOptions.new
options.skip_if_configured = "#ff0000"
result = PrismatIQ.extract_theme("spec/fixtures/ico/golden_png_32.png", options)
puts "   Result with override: #{result.inspect} (should be nil)"
puts

puts "4. Fix theme for accessibility compliance:"
theme_json = "{\"bg\":\"#808080\",\"text\":{\"light\":\"#aaaaaa\",\"dark\":\"#555555\"}}"
puts "   Original: #{theme_json}"
fixed = PrismatIQ.fix_theme(theme_json)
if fixed
  puts "   Fixed: #{fixed}"
end
puts

puts "5. Extract theme with custom quality:"
options = PrismatIQ::ThemeOptions.new
options.quality = 500
result = PrismatIQ.extract_theme("spec/fixtures/ico/golden_png_32.png", options)
if result
  puts "   Background (quality=500): #{result.bg}"
end
puts

puts "6. Clear the cache:"
PrismatIQ.clear_theme_cache
puts "   Cache cleared"
puts

puts "=== All examples completed successfully! ==="
