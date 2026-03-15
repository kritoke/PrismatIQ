require "../cpu_cores"

module PrismatIQ
  struct Config
    property? debug : Bool
    property threads : Int32?
    property merge_chunk : Int32?
    property? ssrf_protection : Bool
    property ssrf_allowlist : Array(String)?

    def initialize(
      @debug : Bool = false,
      @threads : Int32? = nil,
      @merge_chunk : Int32? = nil,
      @ssrf_protection : Bool = true,
      @ssrf_allowlist : Array(String)? = nil
    )
    end

    def self.default : Config
      new(
        debug: ENV["PRISMATIQ_DEBUG"]? == "true" || ENV["PRISMATIQ_DEBUG"]? == "1",
        threads: ENV["PRISMATIQ_THREADS"]?.try(&.to_i),
        merge_chunk: ENV["PRISMATIQ_MERGE_CHUNK"]?.try(&.to_i),
        ssrf_protection: ENV["PRISMATIQ_SSRF_PROTECTION"]? != "false",
        ssrf_allowlist: ENV["PRISMATIQ_SSRF_ALLOWLIST"]?.try(&.split(",").map(&.strip))
      )
    end

    def thread_count_for(height : Int32, requested : Int32) : Int32
      t = requested <= 0 ? (threads || CPU.cores) : requested
      {t, height}.min
    end

    def debug_log(message : String) : Nil
      STDERR.puts message if @debug
    end
  end
end
