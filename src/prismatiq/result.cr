module PrismatIQ
  alias Error = String | Exception

  struct Result(T, E)
    @value : T?
    @error : E?

    private def initialize(@value : T?, @error : E?)
    end

    def self.ok(value : T) : Result(T, E)
      new(value, nil)
    end

    def self.err(error : E) : Result(T, E)
      new(nil, error)
    end

    def ok?
      @value != nil
    end

    def err?
      @error != nil
    end

    def value : T
      raise "Result is an error: #{@error}" unless @value
      @value.as(T)
    end

    def error : E
      raise "Result is ok: #{@value}" unless @error
      @error.as(E)
    end

    def value_or(default : T) : T
      @value || default
    end

    def map(&block : T -> U) : Result(U, E) forall U
      if @value
        Result(U, E).ok(block.call(@value.as(T)))
      else
        Result(U, E).err(@error.as(E))
      end
    end

    def flat_map(&block : T -> Result(U, E)) : Result(U, E) forall U
      if @value
        block.call(@value.as(T))
      else
        Result(U, E).err(@error.as(E))
      end
    end

    def map_error(&block : E -> F) : Result(T, F) forall F
      if @error
        Result(T, F).err(block.call(@error.as(E)))
      else
        Result(T, F).ok(@value.as(T))
      end
    end
  end
end
