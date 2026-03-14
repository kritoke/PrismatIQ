module PrismatIQ
  struct Options
    property color_count : Int32 = 5
    property quality : Int32 = 10
    property threads : Int32 = 0
    property alpha_threshold : UInt8 = Constants::ALPHA_THRESHOLD_DEFAULT

    def initialize(
      @color_count : Int32 = 5,
      @quality : Int32 = 10,
      @threads : Int32 = 0,
      @alpha_threshold : UInt8 = Constants::ALPHA_THRESHOLD_DEFAULT,
    )
    end

    def validate!
      raise ValidationError.new("color_count must be >= 1, got #{@color_count}") if @color_count < 1
      raise ValidationError.new("quality must be >= 1, got #{@quality}") if @quality < 1
      raise ValidationError.new("threads must be >= 0, got #{@threads}") if @threads < 0
    end

    def with_color_count(color_count : Int32) : Options
      Options.new(color_count, quality, threads, alpha_threshold)
    end

    def with_quality(quality : Int32) : Options
      Options.new(color_count, quality, threads, alpha_threshold)
    end

    def with_threads(threads : Int32) : Options
      Options.new(color_count, quality, threads, alpha_threshold)
    end

    def with_alpha_threshold(alpha_threshold : UInt8) : Options
      Options.new(color_count, quality, threads, alpha_threshold)
    end

    def self.default : Options
      new
    end
  end
end
