module PrismatIQ
  module Constants
    ALPHA_THRESHOLD_DEFAULT = 125_u8
    HISTOGRAM_SIZE          =  32768
    RGBA_CHANNELS           =      4
    MAX_FILE_SIZE           = 100 * 1024 * 1024 # 100MB

    LUMINANCE_THRESHOLD = 0.5

    module ThemeExtraction
      GRAY_STEP           = 5
      LIGHT_TEXT_FALLBACK = [238, 238, 238]
      DARK_TEXT_FALLBACK  = [17, 17, 17]
    end

    module ParallelProcessing
      SMALL_IMAGE_THRESHOLD  =   100_000
      MEDIUM_IMAGE_THRESHOLD = 1_000_000
      LARGE_IMAGE_THRESHOLD  = 2_000_000

      MIN_CHUNK_SIZE_SMALL =  10_000
      MAX_CHUNK_SIZE_SMALL = 100_000
      MIN_CHUNK_SIZE_LARGE =  50_000
      MAX_CHUNK_SIZE_LARGE = 500_000

      THREAD_COUNT_MEDIUM_THRESHOLD = 500_000
      GOOD_PARALLELISM              =       4
      MAX_THREAD_COUNT              =       8
    end

    module Accessibility
      COLOR_SUGGESTION_STEP =  10
      ADJUSTMENT_ITERATIONS = 100

      FALLBACK_BLACK      = {0, 0, 0}
      FALLBACK_WHITE      = {255, 255, 255}
      FALLBACK_NEAR_BLACK = {30, 30, 30}
      FALLBACK_NEAR_WHITE = {225, 225, 225}
    end

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
