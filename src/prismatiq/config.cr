require "../cpu_cores"

module PrismatIQ
  struct Config
    property? debug : Bool
    property threads : Int32?
    property merge_chunk : Int32?

    def initialize(@debug : Bool = false, @threads : Int32? = nil, @merge_chunk : Int32? = nil)
    end

    def self.default : Config
      new(
        debug: ENV["PRISMATIQ_DEBUG"]? == "true" || ENV["PRISMATIQ_DEBUG"]? == "1",
        threads: ENV["PRISMATIQ_THREADS"]?.try(&.to_i),
        merge_chunk: ENV["PRISMATIQ_MERGE_CHUNK"]?.try(&.to_i)
      )
    end

    def thread_count_for(height : Int32, requested : Int32) : Int32
      t = requested <= 0 ? (threads || CPU.cores) : requested
      {t, height}.min
    end
  end
end
