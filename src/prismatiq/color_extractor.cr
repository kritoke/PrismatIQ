module PrismatIQ
  module ColorExtractor
    struct Options
      property sample_size : Int32 = 1000
      property alpha_threshold : UInt8 = 1_u8
    end

    def self.extract_from_buffer(pixels : Slice(UInt8), width : Int32, height : Int32, options : Options = Options.new, config : Config = Config.default) : Array(RGB)?
      return if width <= 0 || height <= 0

      total_i64 = width.to_i64 * height.to_i64
      expected_size = total_i64 * 4
      return if total_i64 > Int32::MAX.to_i64 || pixels.size < expected_size

      total = total_i64.to_i32
      sample_size = options.sample_size > 0 ? options.sample_size : 1000
      step = (total.to_f / sample_size.to_f).ceil.to_i32
      step = 1 if step < 1

      r_total, g_total, b_total, count = sample_pixels(pixels, total, step, options, config)

      return if count == 0

      r_avg = (r_total / count.to_i64).to_i32.clamp(0, 255)
      g_avg = (g_total / count.to_i64).to_i32.clamp(0, 255)
      b_avg = (b_total / count.to_i64).to_i32.clamp(0, 255)

      [RGB.new(r_avg, g_avg, b_avg)]
    rescue ex : ArgumentError | OverflowError
      config.log_debug "ColorExtractor.extract_from_buffer: exception: #{ex.class.name}: #{ex.message}"
      nil
    end

    private def self.sample_pixels(pixels : Slice(UInt8), total : Int32, step : Int32, options : Options, config : Config) : Tuple(Int64, Int64, Int64, Int32)
      r_total = 0_i64
      g_total = 0_i64
      b_total = 0_i64
      count = 0_i32

      p = 0_i32
      while p < total
        idx = p * 4
        if idx + 3 < pixels.size
          a = pixels[idx + 3]
          if a >= options.alpha_threshold
            r = pixels[idx].to_i32
            g = pixels[idx + 1].to_i32
            b = pixels[idx + 2].to_i32

            r, g, b = process_alpha_channel(r, g, b, a)
            next unless r && g && b

            r_total += r.to_i64
            g_total += g.to_i64
            b_total += b.to_i64
            count += 1
          end
        else
          config.log_debug "ColorExtractor.extract_from_buffer: skipping out-of-bounds idx=#{idx} pixels.size=#{pixels.size}"
        end

        p += step
      end

      {r_total, g_total, b_total, count}
    end

    private def self.process_alpha_channel(r : Int32, g : Int32, b : Int32, a : UInt8) : Tuple(Int32?, Int32?, Int32?)
      return {r, g, b} if a == 255_u8

      af = a.to_f / 255.0
      if af > 0.001
        r = (r.to_f / af).to_i32.clamp(0, 255)
        g = (g.to_f / af).to_i32.clamp(0, 255)
        b = (b.to_f / af).to_i32.clamp(0, 255)
        {r, g, b}
      else
        {nil, nil, nil}
      end
    end

    def self.extract_from_buffer(pixels : Array(UInt8), width : Int32, height : Int32, options : Options = Options.new, config : Config = Config.default) : Array(RGB)?
      extract_from_buffer(pixels.to_slice, width, height, options, config)
    end
  end
end
