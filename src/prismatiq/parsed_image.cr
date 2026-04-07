module PrismatIQ
  struct ParsedImage
    getter width : Int32
    getter height : Int32
    getter pixels : Slice(UInt8)

    def initialize(@width : Int32, @height : Int32, @pixels : Slice(UInt8))
    end
  end
end
