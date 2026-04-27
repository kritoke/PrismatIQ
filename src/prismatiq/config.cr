require "../cpu_cores"

module PrismatIQ
  # Token bucket rate limiter for HTTP request throttling.
  class RateLimiter
    @tokens : Float64
    @last_refill : Time::Span
    @mutex : Mutex
    @burst : Int32

    def initialize(@rate : Int32, burst : Int32? = nil)
      @burst = burst || @rate
      @tokens = @burst.to_f64
      # Using Time.monotonic instead of Time::Instant due to Crystal 1.18.2 constraint
      @last_refill = Time.monotonic
      @mutex = Mutex.new
    end

    def acquire : Bool
      @mutex.synchronize do
        refill_tokens
        if @tokens >= 1.0
          @tokens -= 1.0
          true
        else
          false
        end
      end
    end

    def wait_time : Time::Span
      @mutex.synchronize do
        refill_tokens
        if @tokens >= 1.0
          Time::Span.zero
        else
          seconds = (1.0 - @tokens) / @rate.to_f64
          Time::Span.new(seconds: seconds)
        end
      end
    end

    def wait_for_token(timeout_seconds : Float64 = 5.0) : Bool
      deadline = Time.monotonic + Time::Span.new(seconds: timeout_seconds)
      sleep_time = 0.001
      max_sleep = 0.1
      while Time.monotonic < deadline
        return true if acquire
        sleep(sleep_time.seconds)
        sleep_time = {sleep_time * 1.5, max_sleep}.min
      end
      false
    end

    private def refill_tokens : Nil
      # Using Time.monotonic instead of Time::Instant due to Crystal 1.18.2 constraint
      now = Time.monotonic
      elapsed = (now - @last_refill).total_seconds
      return if elapsed <= 0

      @tokens = {@tokens + elapsed * @rate.to_f64, @burst.to_f64}.min
      @last_refill = now
    end
  end

  # Configuration for PrismatIQ runtime behavior.
  struct Config
    @@default : Config?
    @@default_mutex = Mutex.new

    # Enable debug logging
    property? debug : Bool
    property? ssrf_protection : Bool
    # Allowed hosts for URL fetching (bypasses SSRF check)
    property ssrf_allowlist : Array(String)?
    # Rate limit for HTTP requests per second
    property rate_limit : Int32
    # Internal rate limiter instance
    property rate_limiter : RateLimiter?
    # Maximum image dimensions (pixels) to prevent excessive memory from decompressed images
    property max_image_width : Int32
    property max_image_height : Int32

    def initialize(
      @debug : Bool = false,
      @ssrf_protection : Bool = true,
      @ssrf_allowlist : Array(String)? = nil,
      @rate_limit : Int32 = 10,
      @max_image_width : Int32 = 8192,
      @max_image_height : Int32 = 8192,
    )
      @max_image_width = 1 if @max_image_width < 1
      @max_image_height = 1 if @max_image_height < 1
      if @rate_limit > 0
        @rate_limiter = RateLimiter.new(@rate_limit)
      end
    end

    def self.default : Config
      @@default_mutex.synchronize do
        @@default ||= begin
          rate_limit_val = ENV["PRISMATIQ_RATE_LIMIT"]?.try(&.to_i?) || 10
          new(
            debug: ENV["PRISMATIQ_DEBUG"]? == "true" || ENV["PRISMATIQ_DEBUG"]? == "1",
            ssrf_protection: ENV["PRISMATIQ_SSRF_PROTECTION"]? != "false",
            ssrf_allowlist: ENV["PRISMATIQ_SSRF_ALLOWLIST"]?.try(&.split(",").map(&.strip)),
            rate_limit: rate_limit_val,
            max_image_width: ENV["PRISMATIQ_MAX_IMAGE_WIDTH"]?.try(&.to_i?) || 8192,
            max_image_height: ENV["PRISMATIQ_MAX_IMAGE_HEIGHT"]?.try(&.to_i?) || 8192,
          )
        end
      end
    end

    def log_debug(message : String) : Nil
      STDERR.puts message if @debug
    end

    def debug_log? : Bool
      @debug
    end

    def rate_limit_allow? : Bool
      if limiter = @rate_limiter
        limiter.acquire
      else
        true
      end
    end

    def rate_limit_wait_time : Time::Span
      return Time::Span.zero unless @rate_limiter
      @rate_limiter.wait_time
    end
  end
end
