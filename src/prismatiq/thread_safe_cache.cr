module PrismatIQ
  class ThreadSafeCache(K, V)
    @cache : Hash(K, V)
    @mutex : Mutex
    @order : Array(K)
    @max_entries : Int32?

    def initialize(max_entries : Int32? = nil)
      @cache = Hash(K, V).new
      @mutex = Mutex.new
      @order = Array(K).new
      @max_entries = max_entries
    end

    def get_or_compute(key : K, &block : -> V) : V
      @mutex.synchronize do
        cached = @cache[key]?
        return cached if cached

        value = block.call
        evict_if_needed
        @cache[key] = value
        @order << key
        value
      end
    end

    def clear : Nil
      @mutex.synchronize do
        @cache.clear
        @order.clear
      end
    end

    def size : Int32
      @mutex.synchronize do
        @cache.size
      end
    end

    def empty? : Bool
      @mutex.synchronize do
        @cache.empty?
      end
    end

    def has_key?(key : K) : Bool
      @mutex.synchronize do
        @cache.has_key?(key)
      end
    end

    def [](key : K) : V?
      @mutex.synchronize do
        @cache[key]?
      end
    end

    def []=(key : K, value : V) : V
      @mutex.synchronize do
        unless @cache.has_key?(key)
          evict_if_needed
          @order << key
        end
        @cache[key] = value
        value
      end
    end

    private def evict_if_needed : Nil
      return unless max = @max_entries
      return if @cache.size < max
      evict_oldest
    end

    private def evict_oldest : Nil
      key = @order.shift?
      @cache.delete(key) if key
    end

    private getter max_entries : Int32?
  end
end
