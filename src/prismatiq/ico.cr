module PrismatIQ
  # Minimal ICO reader: prefer PNG-encoded icon entries.
  # Public helper: get_palette_from_ico(path, color_count = 5, quality = 10, threads = 0)

  private def self.read_u16_le(slice : Slice(UInt8), idx : Int) : Int32
    (slice[idx].to_u32 | (slice[idx + 1].to_u32 << 8)).to_i32
  end

  # Return a 32-bit unsigned little-endian value as UInt64 to avoid
  # accidental 32-bit signed overflows when working with file offsets/sizes.
  private def self.read_u32_le(slice : Slice(UInt8), idx : Int) : UInt64
    (slice[idx].to_u64 | (slice[idx + 1].to_u64 << 8) | (slice[idx + 2].to_u64 << 16) | (slice[idx + 3].to_u64 << 24)).to_u64
  end

  # Return a 32-bit signed little-endian value as Int64 for safer arithmetic
  # when calculating dimensions and signed header fields.
  private def self.read_i32_le(slice : Slice(UInt8), idx : Int) : Int64
    (slice[idx].to_u64 | (slice[idx + 1].to_u64 << 8) | (slice[idx + 2].to_u64 << 16) | (slice[idx + 3].to_u64 << 24)).to_i64
  end

  private def self.mask_to_shift_and_bits(mask : UInt32) : Tuple(Int32, Int32)
    return {-1, 0} if mask == 0_u32
    shift = 0
    m = mask
    while (m & 1_u32) == 0_u32
      m >>= 1
      shift += 1
    end
    bits = 0
    while (m & 1_u32) == 1_u32
      m >>= 1
      bits += 1
    end
    {shift, bits}
  end

  def self.get_palette_from_ico(path : String, color_count : Int32 = 5, quality : Int32 = 10, threads : Int32 = 0) : Array(RGB)
    begin
      data_str = File.read(path)
    rescue ex : Exception
      STDERR.puts "ICO: failed to read path #{path}: #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
      return [RGB.new(0, 0, 0)]
    end
    bytes = data_str.to_slice

    # ICONDIR header must be at least 6 bytes; if not an ICO, fall back to CrImage
    if bytes.size < 6
      begin
        begin
          img = CrImage.read(path)
        rescue ex : Exception
          STDERR.puts "ICO: CrImage.read fallback failed for #{path}: #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
          img = nil
        end
        return [RGB.new(0, 0, 0)] unless img
        # Delegate to path-based get_palette which handles IO and decoding
        return get_palette(path, color_count, quality)
      rescue ex : Exception
        STDERR.puts "ICO: unexpected error in fallback decode: #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
        return [RGB.new(0, 0, 0)]
      end
    end

    reserved = read_u16_le(bytes, 0)
    typ = read_u16_le(bytes, 2)
    count = read_u16_le(bytes, 4)

    if reserved != 0 || (typ != 1 && typ != 2) || count <= 0
      # Not an ICO; try generic image decoding
      begin
        begin
          img = CrImage.read(path)
        rescue ex : Exception
          STDERR.puts "ICO: CrImage.read fallback decode failed for #{path}: #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
          img = nil
        end
        return [RGB.new(0, 0, 0)] unless img
        return get_palette(path, color_count, quality)
      rescue ex : Exception
        STDERR.puts "ICO: unexpected error in fallback decode: #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
        return [RGB.new(0, 0, 0)]
      end
    end

    # Read first entry that looks like PNG (search entries for PNG data)
    entry_base = 6
    found_slice = nil
    found_w = 0
    found_h = 0
    i = 0
    while i < count && (entry_base + 16) <= bytes.size
      off = entry_base + i * 16
      width = bytes[off].to_u32
      height = bytes[off + 1].to_u32
      size = read_u32_le(bytes, off + 8)
      image_offset = read_u32_le(bytes, off + 12)

      if image_offset >= 0 && (image_offset + size) <= bytes.size
        # get image data slice
        img_slice = bytes[image_offset, size]
        # PNG signature
        if size >= 8 && img_slice[0] == 0x89_u8 && img_slice[1] == 0x50_u8 && img_slice[2] == 0x4E_u8 && img_slice[3] == 0x47_u8
          found_slice = img_slice
          found_w = width.to_i32 == 0 ? 256 : width.to_i32
          found_h = height.to_i32 == 0 ? 256 : height.to_i32
          break
        end
      end

      i += 1
    end

    # If a PNG entry was found, write the PNG bytes to a temp file and delegate
    # to the file-based get_palette path. Writing a temp file keeps behavior
    # deterministic and avoids fragile in-memory type dispatch at compile-time.
    if found_slice
      begin
        # Size guard: avoid allocating or writing extremely large embedded images
        max_entry_size = 50_000_000 # 50 MB default limit; make configurable later
        if found_slice.size > max_entry_size
          STDERR.puts "PrismatIQ: ICO PNG entry too large (#{found_slice.size} bytes)" if ENV["PRISMATIQ_DEBUG"]?
          return [RGB.new(0, 0, 0)]
        end

        self.debug_log("ICO: found PNG entry w=#{found_w} h=#{found_h} size=#{found_slice.size}")

        # Create a secure temp file and write the PNG slice atomically.
        begin
          png_path = PrismatIQ::TempfileHelper.create_and_write("prismatiq_ico_", found_slice)
          if !png_path
            STDERR.puts "PrismatIQ: failed to create secure temp PNG file" if ENV["PRISMATIQ_DEBUG"]?
          else
            begin
              img = CrImage.read(png_path)
              if img
                # Normalize then compute palette (same as previous flow)
                rgba_image : CrImage::RGBA? = nil
                begin
                  rgba_image = CrImage::Pipeline.new(img).result
                rescue ex : Exception
                  self.debug_log("ICO: Pipeline normalization failed: #{ex.class} #{ex.message}, falling back to file-based decoding")
                  return get_palette(png_path, color_count, quality) rescue [RGB.new(0,0,0)]
                end

                unless rgba_image
                  # Pipeline returned nil for some reason; delegate to file-based decoder
                  return get_palette(png_path, color_count, quality) rescue [RGB.new(0,0,0)]
                end

                non_nil_rgba = rgba_image.not_nil!
                w = non_nil_rgba.bounds.width.to_i32
                h = non_nil_rgba.bounds.height.to_i32
                src = non_nil_rgba.pix
                pixels = Slice(UInt8).new(src.size)
                i = 0
                while i < src.size
                  pixels[i] = src[i]
                  i += 1
                end

                pal = get_palette_from_buffer(pixels, w, h, color_count, quality, threads)
                if pal.size == 1 && pal[0].r == 0 && pal[0].g == 0 && pal[0].b == 0
                  return get_palette(png_path, color_count, quality) rescue pal
                end
                return pal
              end
            ensure
              File.delete(png_path) rescue nil
            end
          end
        rescue ex : Exception
          STDERR.puts "PrismatIQ: secure temp file creation failed: #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
        end
      rescue ex : Exception
        STDERR.puts "PrismatIQ: failed to create or write temp PNG from ICO: #{ex.message}" if ENV["PRISMATIQ_DEBUG"]?
        # Fall through to BMP parsing below
      end
    end

    # No PNG entry found: attempt to parse BMP/DIB ICO entries in-memory
    bmp_candidate = nil
    bmp_candidate_area = 0_i32
    bmp_candidate_bitcount = 0_i32
    bmp_w = 0
    bmp_h = 0
    bmp_slice = nil

    # scan entries for BMP-like BITMAPINFOHEADER
    i = 0
    while i < count && (entry_base + 16) <= bytes.size
      off = entry_base + i * 16
      width = bytes[off].to_u32
      height = bytes[off + 1].to_u32
      size = read_u32_le(bytes, off + 8)
      image_offset = read_u32_le(bytes, off + 12)

      if image_offset >= 0 && (image_offset + size) <= bytes.size && size >= 40
        hdr = bytes[image_offset, size]
        header_size = read_u32_le(hdr, 0)
        if header_size >= 40 && size >= header_size
          w = read_i32_le(hdr, 4)
          h_total = read_i32_le(hdr, 8)
          # ICO BMP stores height as doubled (image + AND mask)
          h = (h_total / 2).to_i32
          bit_count = read_u16_le(hdr, 14)
          # basic sanity checks
          if w > 0 && h > 0 && bit_count >= 24
            area = w * h
            if area > bmp_candidate_area || (area == bmp_candidate_area && bit_count > bmp_candidate_bitcount)
              bmp_candidate_area = area
              bmp_candidate_bitcount = bit_count
              bmp_candidate = {offset: image_offset, size: size}
              bmp_w = w
              bmp_h = h
              bmp_slice = hdr
            end
          end
        end
      end

      i += 1
    end

    if !bmp_slice
      # nothing found; fall back to returning default
      return [RGB.new(0, 0, 0)]
    end

    # Parse BMP/DIB pixel data
    header_size = read_u32_le(bmp_slice, 0)
    bit_count = read_u16_le(bmp_slice, 14)
    compression = read_u32_le(bmp_slice, 16)

    # Reject compressed or unsupported bitfields
    if compression != 0
      STDERR.puts "PrismatIQ: unsupported BMP compression=#{compression} in ICO entry" if ENV["PRISMATIQ_DEBUG"]?
      return [RGB.new(0, 0, 0)]
    end

    # Determine top-down vs bottom-up and actual height
    h_total = read_i32_le(bmp_slice, 8)
    top_down = false
    if h_total < 0
      top_down = true
      bmp_h = (-h_total) / 2
    else
      bmp_h = (h_total / 2)
    end

    bytes_per_pixel = (bit_count / 8).to_i32

    # Prepare bitfields masks if present
    red_mask = 0_u32
    green_mask = 0_u32
    blue_mask = 0_u32
    alpha_mask = 0_u32
    if compression == 3
      # masks typically follow the BITMAPINFOHEADER at offset 40
      # Ensure slice has enough bytes
      if bmp_slice.size >= 52
        red_mask = read_u32_le(bmp_slice, 40).to_u32
        green_mask = read_u32_le(bmp_slice, 44).to_u32
        blue_mask = read_u32_le(bmp_slice, 48).to_u32
        if bmp_slice.size >= 56
          alpha_mask = read_u32_le(bmp_slice, 52).to_u32
        end
      end
    end

    # Palette handling for <=8bpp
    palette = [] of Tuple(UInt8, UInt8, UInt8, UInt8)
    palette_entries = 0
    if bit_count <= 8
      # colors used field is at offset 32 in BITMAPINFOHEADER (if available)
      colors_used = 0_u32
      if header_size >= 40 && bmp_slice.size >= 36
        colors_used = read_u32_le(bmp_slice, 32)
      end
      palette_entries = colors_used > 0 ? colors_used.to_i32 : (1 << bit_count)
      pal_off = header_size
      i = 0
      while i < palette_entries
        po = pal_off + i * 4
        break if po + 3 >= bmp_slice.size
        # BMP palette entries are in B G R order, with optional reserved byte
        b = bmp_slice[po]
        g = bmp_slice[po + 1]
        r = bmp_slice[po + 2]
        a = bmp_slice[po + 3]
        palette << {r, g, b, a}
        i += 1
      end
      # If the palette was not present, ensure length matches expected entries
      while palette.size < (1 << bit_count)
        palette << {0_u8, 0_u8, 0_u8, 255_u8}
      end
    end

    # Pixel data offset: header + palette size (palette entries * 4)
    pixel_data_offset = header_size + (palette_entries * 4)
    # Row size in bytes (each scanline aligned to 4 bytes)
    row_size = ((bmp_w * bit_count + 31) // 32) * 4

    # AND mask offset follows XOR pixel data
    xor_data_size = row_size * bmp_h
    and_mask_offset = pixel_data_offset + xor_data_size
    and_row_size = ((bmp_w + 31) // 32) * 4

    # Build RGBA buffer
    total = bmp_w.to_i32 * bmp_h.to_i32 * 4
    pixels = Slice(UInt8).new(total)

    # Optimized pixel extraction paths for common bpp values
    if (bit_count == 32 || bit_count == 24) && compression == 0
      # fast path: iterate rows and copy pixels with minimal bounds checks
      src_size = bmp_slice.size
      y = 0
      while y < bmp_h
        src_row = top_down ? y : (bmp_h - 1 - y)
        row_start = (pixel_data_offset + src_row * row_size).to_i32
        dest_idx = (y * bmp_w * 4).to_i32
        if bit_count == 32
           src_off = row_start.to_i32
         x = 0_i32
         while x < bmp_w
            if src_off + 3 < src_size
              b = bmp_slice[src_off]
              g = bmp_slice[src_off + 1]
              r = bmp_slice[src_off + 2]
              a = bmp_slice[src_off + 3]
            else
              r = 0_u8; g = 0_u8; b = 0_u8; a = 0_u8
            end
            pixels[dest_idx] = r
            pixels[dest_idx + 1] = g
            pixels[dest_idx + 2] = b
            pixels[dest_idx + 3] = a
            src_off += 4
            dest_idx += 4
            x += 1
          end
        else # 24bpp
           src_off = row_start.to_i32
          x = 0
          while x < bmp_w
            if src_off + 2 < src_size
              b = bmp_slice[src_off]
              g = bmp_slice[src_off + 1]
              r = bmp_slice[src_off + 2]
            else
              r = 0_u8; g = 0_u8; b = 0_u8
            end
            pixels[dest_idx] = r
            pixels[dest_idx + 1] = g
            pixels[dest_idx + 2] = b
            pixels[dest_idx + 3] = 255_u8
            src_off += 3
            dest_idx += 4
            x += 1
          end
        end
        y += 1
      end
    else
      # generic (paletted or unusual bpp) slower path
      y = 0
      while y < bmp_h
         src_row = top_down ? y : (bmp_h - 1 - y)
         row_start = (pixel_data_offset + src_row * row_size).to_i32
        x = 0
        while x < bmp_w
          px_r = 0_u8
          px_g = 0_u8
          px_b = 0_u8
          px_a = 255_u8

          if bit_count == 8
             off = row_start + x
            if off < bmp_slice.size
              idx = bmp_slice[off].to_i
              if idx < palette.size
                px_r, px_g, px_b, pal_a = palette[idx]
                if pal_a && pal_a != 0_u8
                  px_a = pal_a
                end
              end
            end
          elsif bit_count == 4
             off = row_start + (x / 2)
             if off < bmp_slice.size
               byte = bmp_slice[off.to_i]
              idx = if (x % 2) == 0
                      (byte >> 4) & 0x0F
                    else
                      byte & 0x0F
                    end
              if idx < palette.size
                px_r, px_g, px_b, pal_a = palette[idx]
                if pal_a && pal_a != 0_u8
                  px_a = pal_a
                end
              end
            end
          elsif bit_count == 1
             off = row_start + (x / 8)
             if off < bmp_slice.size
               byte = bmp_slice[off.to_i]
              shift = 7 - (x % 8)
              idx = (byte >> shift) & 0x01
              if idx < palette.size
                px_r, px_g, px_b, pal_a = palette[idx]
                if pal_a && pal_a != 0_u8
                  px_a = pal_a
                end
              end
            end
          elsif bit_count == 32 && compression == 3 && (red_mask != 0_u32 || green_mask != 0_u32 || blue_mask != 0_u32)
            off = row_start + x * 4
            if off + 3 < bmp_slice.size
              val = bmp_slice[off].to_u32 | (bmp_slice[off + 1].to_u32 << 8) | (bmp_slice[off + 2].to_u32 << 16) | (bmp_slice[off + 3].to_u32 << 24)
              r_shift, r_bits = mask_to_shift_and_bits(red_mask)
              g_shift, g_bits = mask_to_shift_and_bits(green_mask)
              b_shift, b_bits = mask_to_shift_and_bits(blue_mask)
              a_shift, a_bits = mask_to_shift_and_bits(alpha_mask)
              if r_bits > 0
                raw = ((val & red_mask) >> r_shift).to_i
                px_r = ((raw * 255) / ((1 << r_bits) - 1)).to_u8
              end
              if g_bits > 0
                raw = ((val & green_mask) >> g_shift).to_i
                px_g = ((raw * 255) / ((1 << g_bits) - 1)).to_u8
              end
              if b_bits > 0
                raw = ((val & blue_mask) >> b_shift).to_i
                px_b = ((raw * 255) / ((1 << b_bits) - 1)).to_u8
              end
              if a_bits > 0
                raw = ((val & alpha_mask) >> a_shift).to_i
                px_a = ((raw * 255) / ((1 << a_bits) - 1)).to_u8
              end
            end
          else
            # unsupported/unknown bpp: leave pixel as black transparent
            px_r = 0_u8; px_g = 0_u8; px_b = 0_u8; px_a = 0_u8
          end

          # Apply AND mask transparency if present and alpha still fully opaque
           if (and_mask_offset + (src_row * and_row_size)).to_i32 < bmp_slice.size
             mask_row_start = (and_mask_offset + src_row * and_row_size).to_i32
             mask_byte = mask_row_start + (x / 8)
             if mask_byte < bmp_slice.size
               mask_val = bmp_slice[mask_byte.to_i]
              bit = 7 - (x % 8)
              if ((mask_val >> bit) & 1) == 1
                px_a = 0_u8
              end
            end
          end

          dest_idx = (y * bmp_w + x) * 4
          pixels[dest_idx] = px_r
          pixels[dest_idx + 1] = px_g
          pixels[dest_idx + 2] = px_b
          pixels[dest_idx + 3] = px_a

          x += 1
        end

        y += 1
      end
    end

    # Delegate to buffer-based palette extraction
    get_palette_from_buffer(pixels, bmp_w.to_i32, bmp_h.to_i32, color_count, quality, threads)
  end

  # Debug helper: gated by PRISMATIQ_DEBUG env var
  private def self.debug_log(*parts)
    if ENV.has_key?("PRISMATIQ_DEBUG")
      STDERR.puts parts.join(" ")
    end
  end
end
