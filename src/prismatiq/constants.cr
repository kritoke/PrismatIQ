module PrismatIQ
  module Constants
    ALPHA_THRESHOLD_DEFAULT = 125_u8
    HISTOGRAM_SIZE          =  32768
    RGBA_CHANNELS           =      4
    MAX_FILE_SIZE           = 100 * 1024 * 1024 # 100MB

    LUMINANCE_THRESHOLD = 0.5

    module WCAG
      CONTRAST_RATIO_AA        = 4.5
      CONTRAST_RATIO_AA_LARGE  = 3.0
      CONTRAST_RATIO_AAA       = 7.0
      CONTRAST_RATIO_AAA_LARGE = 4.5
    end

    module YIQ
      Y_FROM_R =  0.299
      Y_FROM_G =  0.587
      Y_FROM_B =  0.114
      I_FROM_R =  0.596
      I_FROM_G = -0.274
      I_FROM_B = -0.322
      Q_FROM_R =  0.211
      Q_FROM_G = -0.523
      Q_FROM_B =  0.312

      R_FROM_Y =    1.0
      R_FROM_I =  0.956
      R_FROM_Q =  0.621
      G_FROM_Y =    1.0
      G_FROM_I = -0.272
      G_FROM_Q = -0.647
      B_FROM_Y =    1.0
      B_FROM_I = -1.106
      B_FROM_Q =  1.703
    end
  end
end
