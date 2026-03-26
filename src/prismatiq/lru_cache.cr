module PrismatIQ
  # Generic LRU (Least Recently Used) cache with fixed capacity.
  #
  # Provides O(1) average time complexity for both get and put operations
  # by combining a hash table for lookups with a doubly-linked list for
  # maintaining access order. Automatically evicts the least recently used
  # entry when capacity is exceeded.
  #
  # ### Features
  # - Generic type parameters for key (K) and value (V)
  # - Fixed capacity with automatic LRU eviction
  # - O(1) get and put operations
  # - Efficient memory usage bounded by capacity
  #
  # ### Performance Note
  # Uses a hash table for O(1) key lookups and a doubly-linked list for
  # O(1) updates to access order. This provides optimal performance for
  # both read and write operations.
  #
  # ### Example
  # ```
  # cache = LRUCache(String, Int32).new(capacity: 100)
  # cache.put("key1", 42)
  # value = cache.get("key1") # => 42
  # cache.put("key2", 100)    # May evict least recently used if at capacity
  # ```
  class LRUCache(K, V)
    # Internal node for doubly-linked list
    private class Node(K, V)
      property key : K
      property value : V
      property prev : Node(K, V)?
      property next : Node(K, V)?

      def initialize(@key : K, @value : V)
        @prev = nil
        @next = nil
      end
    end

    # Maximum number of entries in the cache
    @capacity : Int32

    # Hash table for O(1) key lookups
    @cache : Hash(K, Node(K, V))

    # Most recently used node (head of linked list)
    @head : Node(K, V)?

    # Least recently used node (tail of linked list)
    @tail : Node(K, V)?

    # Creates a new LRUCache instance with the specified capacity.
    #
    # @param capacity the maximum number of entries to store
    def initialize(@capacity : Int32)
      raise ArgumentError.new("Capacity must be positive") if capacity <= 0
      @cache = Hash(K, Node(K, V)).new
      @head = nil
      @tail = nil
    end

    # Retrieves the value for the given key and marks it as most recently used.
    #
    # Returns nil if the key is not found in the cache.
    #
    # @param key the cache key
    # @return the cached value or nil if not found
    def get(key : K) : V?
      node = @cache[key]?
      return nil unless node

      move_to_head(node)
      node.value
    end

    # Inserts or updates a key-value pair in the cache.
    #
    # If the key already exists, updates its value and moves it to the most
    # recent position. If the cache is at capacity, evicts the least recently
    # used entry before inserting.
    #
    # @param key the cache key
    # @param value the value to store
    # @return the stored value
    def put(key : K, value : V) : V
      node = @cache[key]?

      if node
        # Key exists: update value and move to head
        node.value = value
        move_to_head(node)
        return value
      end

      # Key doesn't exist: create new node
      new_node = Node(K, V).new(key, value)

      # Evict if at capacity
      if @cache.size >= @capacity
        evict_lru
      end

      # Add new node to cache and linked list
      @cache[key] = new_node
      add_to_head(new_node)

      value
    end

    # Returns the number of entries currently in the cache.
    #
    # @return the number of key-value pairs
    def size : Int32
      @cache.size
    end

    # Returns true if the cache contains no entries.
    #
    # @return true if cache is empty
    def empty? : Bool
      @cache.empty?
    end

    # Returns true if the cache contains the specified key.
    #
    # Does not affect the access order (key is not marked as recently used).
    #
    # @param key the key to check
    # @return true if the key exists
    def has_key?(key : K) : Bool
      @cache.has_key?(key)
    end

    # Returns the maximum capacity of the cache.
    #
    # @return the capacity
    def capacity : Int32
      @capacity
    end

    # Removes all entries from the cache.
    #
    # @return nil
    def clear : Nil
      @cache.clear
      @head = nil
      @tail = nil
    end

    # Returns all keys in the cache in order from most to least recently used.
    #
    # @return array of keys in access order
    def keys : Array(K)
      result = Array(K).new
      current = @head
      while current
        result << current.key
        current = current.next
      end
      result
    end

    # Returns all values in the cache in order from most to least recently used.
    #
    # @return array of values in access order
    def values : Array(V)
      result = Array(V).new
      current = @head
      while current
        result << current.value
        current = current.next
      end
      result
    end

    # Yields each key-value pair in order from most to least recently used.
    #
    # @yield [key, value] each cache entry
    def each(&block : K, V ->)
      current = @head
      while current
        yield current.key, current.value
        current = current.next
      end
    end

    private def move_to_head(node : Node(K, V))
      return if node == @head

      # Remove node from current position
      remove_node(node)

      # Add to head
      add_to_head(node)
    end

    private def add_to_head(node : Node(K, V))
      node.prev = nil
      node.next = @head

      if head = @head
        head.prev = node
      end

      @head = node

      # If this is the first node, set it as tail too
      @tail = node unless @tail
    end

    private def remove_node(node : Node(K, V))
      prev_node = node.prev
      next_node = node.next

      if prev_node
        prev_node.next = next_node
      else
        # Node is head
        @head = next_node
      end

      if next_node
        next_node.prev = prev_node
      else
        # Node is tail
        @tail = prev_node
      end

      node.prev = nil
      node.next = nil
    end

    private def evict_lru
      return unless tail = @tail

      @cache.delete(tail.key)
      remove_node(tail)

      # Update tail if we removed it
      @tail = tail.prev unless @tail
    end
  end
end
