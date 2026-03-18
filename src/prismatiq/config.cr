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

    def try_consume : Bool
      acquire
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
    # Enable debug logging
    property? debug : Bool
    # Number of threads for parallel processing (nil = auto)
    property threads : Int32?
    # Chunk size for histogram merging
    property merge_chunk : Int32?
    # Enable SSRF protection for URL fetching
    property? ssrf_protection : Bool
    # Allowed hosts for URL fetching (bypasses SSRF check)
    property ssrf_allowlist : Array(String)?
    # Rate limit for HTTP requests per second
    property rate_limit : Int32
    # Internal rate limiter instance
    property rate_limiter : RateLimiter?

    def initialize(
      @debug : Bool = false,
      @threads : Int32? = nil,
      @merge_chunk : Int32? = nil,
      @ssrf_protection : Bool = true,
      @ssrf_allowlist : Array(String)? = nil,
      @rate_limit : Int32 = 10,
    )
      if @rate_limit > 0
        @rate_limiter = RateLimiter.new(@rate_limit)
      end
    end

    def self.default : Config
      rate_limit_val = ENV["PRISMATIQ_RATE_LIMIT"]?.try(&.to_i) || 10
      new(
        debug: ENV["PRISMATIQ_DEBUG"]? == "true" || ENV["PRISMATIQ_DEBUG"]? == "1",
        threads: ENV["PRISMATIQ_THREADS"]?.try(&.to_i),
        merge_chunk: ENV["PRISMATIQ_MERGE_CHUNK"]?.try(&.to_i),
        ssrf_protection: ENV["PRISMATIQ_SSRF_PROTECTION"]? != "false",
        ssrf_allowlist: ENV["PRISMATIQ_SSRF_ALLOWLIST"]?.try(&.split(",").map(&.strip)),
        rate_limit: rate_limit_val
      )
    end

    def thread_count_for(height : Int32, requested : Int32) : Int32
      t = requested <= 0 ? (threads || CPU.cores) : requested
      {t, height}.min
    end

    def debug_log(message : String) : Nil
      STDERR.puts message if @debug
    end

    def rate_limit_allow? : Bool
      @rate_limiter.try(&.acquire) || true
    end

    def rate_limit_wait_time : Time::Span
      return Time::Span.zero unless @rate_limiter
      @rate_limiter.wait_time
    end
  end
end
