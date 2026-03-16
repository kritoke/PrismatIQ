require "../cpu_cores"

module PrismatIQ
  class RateLimiter
    @tokens : Float64
    @last_refill : Time::Instant
    @mutex : Mutex
    @burst : Int32

    def initialize(@rate : Int32, burst : Int32? = nil)
      @burst = burst || @rate
      @tokens = @burst.to_f64
      @last_refill = Time.instant
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
      deadline = Time.instant + Time::Span.new(seconds: timeout_seconds)
      while Time.instant < deadline
        return true if acquire
        sleep 0.05.seconds
      end
      false
    end

    private def refill_tokens : Nil
      now = Time.instant
      elapsed = (now - @last_refill).total_seconds
      return if elapsed <= 0

      @tokens = {@tokens + elapsed * @rate.to_f64, @burst.to_f64}.min
      @last_refill = now
    end
  end

  struct Config
    property? debug : Bool
    property threads : Int32?
    property merge_chunk : Int32?
    property? ssrf_protection : Bool
    property ssrf_allowlist : Array(String)?
    property rate_limit : Int32
    property rate_limiter : RateLimiter?

    def initialize(
      @debug : Bool = false,
      @threads : Int32? = nil,
      @merge_chunk : Int32? = nil,
      @ssrf_protection : Bool = true,
      @ssrf_allowlist : Array(String)? = nil,
      @rate_limit : Int32 = 10
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
