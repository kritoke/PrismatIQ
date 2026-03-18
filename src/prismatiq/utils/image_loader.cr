require "crimage"

module PrismatIQ
  module Utils
    module ImageLoader
      def self.load(path : String) : CrImage::Image
        img = CrImage.read(path)
        CrImage::Pipeline.new(img.as(CrImage::Image)).result
      end

      def self.load(io : IO) : CrImage::Image
        img = CrImage.read(io)
        CrImage::Pipeline.new(img.as(CrImage::Image)).result
      end

      def self.load(image : CrImage::Image) : CrImage::Image
        CrImage::Pipeline.new(image).result
      end
    end
  end
end
