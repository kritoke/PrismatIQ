module PrismatIQ
  # Thread-safe generic cache with lazy computation.
  #
  # Provides a generic thread-safe caching mechanism with lazy computation and mutex synchronization.
  # Supports get_or_compute for lazy initialization and clear for cache invalidation.
  #
  # ### Features
  # - Generic type parameters for key (K) and value (V)
  # - Thread-safe access using Mutex synchronization
  # - Only one thread executes computation for a given key even with concurrent access
  #
  # ### Performance Note
  # Uses double-checked locking pattern to allow concurrent reads while computation
  # happens under the lock. This reduces contention for frequently accessed cache entries.
  #
  # ### Example
  # ```
  # cache = ThreadSafeCache(String, Int32).new
  # result = cache.get_or_compute("key") { expensive_computation }
  # cache.clear
  # ```
  class ThreadSafeCache(K, V)
    # Internal storage for cached key-value pairs
    @cache : Hash(K, V)

    # Mutex for thread-safe access to the cache
    @mutex : Mutex

    # Creates a new ThreadSafeCache instance.
    def initialize
      @cache = Hash(K, V).new
      @mutex = Mutex.new
    end

    # Retrieves the cached value for the given key, or computes and stores it if not present.
    #
    # This method uses double-checked locking for optimal performance:
    # 1. Fast path: check without lock - if cached, return immediately
    # 2. Slow path: acquire lock, double-check, then compute if needed
    #
    # This allows concurrent reads while only serializing writes/computations.
    #
    # @param key the cache key
    # @return the cached or computed value
    def get_or_compute(key : K, &block : -> V) : V
      # Fast path: check without lock
      cached = @cache[key]?
      return cached if cached

      # Slow path: acquire lock and double-check
      @mutex.synchronize do
        # Double-check inside lock to avoid race condition
        cached = @cache[key]?
        return cached if cached

        value = block.call
        @cache[key] = value
        value
      end
    end

    # Clears all cached entries from the cache.
    #
    # After calling this method, all subsequent get_or_compute calls
    # will recompute values as if the cache was newly created.
    #
    # @return nil
    def clear : Nil
      @mutex.synchronize do
        @cache.clear
      end
    end

    # Returns the number of cached entries.
    #
    # @return the number of key-value pairs in the cache
    def size : Int32
      @mutex.synchronize do
        @cache.size
      end
    end

    # Returns true if the cache contains no entries.
    #
    # @return true if the cache is empty
    def empty? : Bool
      @mutex.synchronize do
        @cache.empty?
      end
    end

    # Returns true if the cache contains the specified key.
    #
    # @param key the key to check
    # @return true if the key exists in the cache
    def has_key?(key : K) : Bool
      @mutex.synchronize do
        @cache.has_key?(key)
      end
    end

    # Retrieves the cached value for the given key without computing.
    #
    # Unlike get_or_compute, this method does NOT execute the block
    # if the key is not found. Returns nil if the key is not in the cache.
    #
    # @param key the cache key
    # @return the cached value or nil if not found
    def [](key : K) : V?
      @mutex.synchronize do
        @cache[key]?
      end
    end

    # Directly sets a value in the cache, bypassing lazy computation.
    #
    # This is a "force set" operation that overwrites any existing value
    # for the given key. Use this when you have a pre-computed value that
    # should be cached without going through get_or_compute.
    #
    # Note: This operation is thread-safe and synchronized.
    #
    # @param key the cache key
    # @param value the value to store
    # @return the stored value
    def []=(key : K, value : V) : V
      @mutex.synchronize do
        @cache[key] = value
      end
    end
  end
end
