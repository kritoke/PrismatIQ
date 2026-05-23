module PrismatIQ
  # Thread-safe LRU cache with optional size limit.
  #
  # Note: All public methods acquire @mutex. Private methods like evict_if_needed
  # are designed to be called ONLY from within already-synchronized contexts
  # to avoid deadlock (Crystal's Mutex is not reentrant).
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
        # @cache.size is safe to read here because we're inside @mutex.synchronize
        evict_if_needed_locked(@cache.size)
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
          # @cache.size is safe to read here because we're inside @mutex.synchronize
          evict_if_needed_locked(@cache.size)
          @order << key
        end
        @cache[key] = value
        value
      end
    end

    # Called ONLY from within @mutex.synchronize block - does NOT acquire lock
    private def evict_if_needed_locked(current_size : Int32) : Nil
      return unless max = @max_entries
      return if current_size < max
      evict_oldest_locked
    end

    # Called ONLY from within @mutex.synchronize block - does NOT acquire lock
    private def evict_oldest_locked : Nil
      key = @order.shift?
      @cache.delete(key) if key
    end

    private getter max_entries : Int32?
  end
end
