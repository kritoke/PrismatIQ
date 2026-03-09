module PrismatIQ
  # Centralized YIQ color space conversion module.
  #
  # Provides methods for converting RGB color values to YIQ color space,
  # with support for both full-precision and quantized conversions.
  # This module centralizes all YIQ conversion logic to eliminate duplication
  # across the codebase.
  #
  # ### Color Space
  # The YIQ color space is derived from RGB using NTSC coefficients:
  # - Y (Luma): Perceived brightness
  # - I (In-phase): Orange-cyan hue
  # - Q (Quadrature): Magenta-green hue
  #
  # ### Quantization
  # For histogram-based operations, Y/I/Q values are quantized to 5-bit (0-31)
  # precision, allowing efficient indexing into a 32768-element histogram.
  module YIQConverter
    # Converts RGB values to YIQ color space.
    #
    # Uses standard NTSC coefficients for RGB to YIQ conversion.
    # Returns a Color struct with Float64 Y, I, Q components.
    #
    # @param r the red component (0-255)
    # @param g the green component (0-255)
    # @param b the blue component (0-255)
    # @return a Color with Y, I, Q components as Float64 values
    #
    # ### Example
    # ```
    # color = YIQConverter.from_rgb(255, 128, 64)
    # puts color.y # Brightness component
    # puts color.i # Orange-cyan component
    # puts color.q # Magenta-green component
    # ```
    def self.from_rgb(r : Int32, g : Int32, b : Int32) : Color
      y = (Constants::YIQ::Y_FROM_R * r) + (Constants::YIQ::Y_FROM_G * g) + (Constants::YIQ::Y_FROM_B * b)
      i = (Constants::YIQ::I_FROM_R * r) + (Constants::YIQ::I_FROM_G * g) + (Constants::YIQ::I_FROM_B * b)
      q = (Constants::YIQ::Q_FROM_R * r) + (Constants::YIQ::Q_FROM_G * g) + (Constants::YIQ::Q_FROM_B * b)
      Color.new(y, i, q)
    end

    # Converts RGB values to quantized YIQ color space.
    #
    # Converts RGB to YIQ and quantizes each component to 5-bit precision (0-31).
    # Used for histogram indexing in the MMCQ algorithm.
    #
    # Y/I/Q ranges need to be properly scaled to 0-31:
    # - Y: 0 to 255 (luminance)
    # - I: -152 to 152 (orange-cyan axis)
    # - Q: -134 to 134 (magenta-green axis)
    #
    # @param r the red component (0-255)
    # @param g the green component (0-255)
    # @param b the blue component (0-255)
    # @return a Tuple of quantized Y, I, Q values (each 0-31)
    #
    # ### Example
    # ```
    # y, i, q = YIQConverter.quantize_from_rgb(255, 128, 64)
    # puts y # 0-31
    # puts i # 0-31
    # puts q # 0-31
    # ```
    def self.quantize_from_rgb(r : Int32, g : Int32, b : Int32) : Tuple(Int32, Int32, Int32)
      y = (Constants::YIQ::Y_FROM_R * r) + (Constants::YIQ::Y_FROM_G * g) + (Constants::YIQ::Y_FROM_B * b)
      i = (Constants::YIQ::I_FROM_R * r) + (Constants::YIQ::I_FROM_G * g) + (Constants::YIQ::I_FROM_B * b)
      q = (Constants::YIQ::Q_FROM_R * r) + (Constants::YIQ::Q_FROM_G * g) + (Constants::YIQ::Q_FROM_B * b)

      # Scale Y from [0, 255] to [0, 31]
      y_q = ((y / 255.0) * 31).round.to_i.clamp(0, 31)

      # Scale I from [-152, 152] to [0, 31]
      i_q = (((i + 152.0) / 304.0) * 31).round.to_i.clamp(0, 31)

      # Scale Q from [-134, 134] to [0, 31]
      q_q = (((q + 134.0) / 268.0) * 31).round.to_i.clamp(0, 31)

      {y_q, i_q, q_q}
    end

    # Converts quantized YIQ values to a histogram index.
    #
    # Uses bit shifting to pack three 5-bit values into a single 15-bit index.
    # The encoding is: (y << 10) | (i << 5) | q
    #
    # @param y the quantized Y component (0-31)
    # @param i the quantized I component (0-31)
    # @param q the quantized Q component (0-31)
    # @return the histogram index (0-32767)
    #
    # ### Example
    # ```
    # index = YIQConverter.to_index(10, 20, 5)
    # puts index # Corresponds to Y=10, I=20, Q=5 in histogram
    # ```
    def self.to_index(y : Int32, i : Int32, q : Int32) : Int32
      (y << 10) | (i << 5) | q
    end
  end
end
