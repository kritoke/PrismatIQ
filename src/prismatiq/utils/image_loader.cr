require "crimage"

module PrismatIQ
  module Utils
    module ImageLoader
      def self.load(path : String) : CrImage::Image
        img = CrImage.read(path)
        normalize(img)
      end

      def self.load(io : IO) : CrImage::Image
        img = CrImage.read(io)
        normalize(img)
      end

      def self.load(image : CrImage::Image) : CrImage::Image
        normalize(image)
      end

      def self.read(path : String) : CrImage::Image
        CrImage.read(path).as(CrImage::Image)
      end

      def self.read(io : IO) : CrImage::Image
        CrImage.read(io).as(CrImage::Image)
      end

      def self.normalize(img : CrImage::Image) : CrImage::Image
        CrImage::Pipeline.new(img).result
      end
    end
  end
end
