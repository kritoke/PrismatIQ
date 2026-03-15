require "json"
require "yaml"

module PrismatIQ
  enum ErrorType
    FileNotFound
    InvalidImagePath
    UnsupportedFormat
    CorruptedImage
    InvalidOptions
    ProcessingFailed
    SSRFBlocked
  end

  class SSRFError < Exception
    getter url : String
    getter ip : String
    getter reason : String

    def initialize(@url : String, @ip : String, @reason : String)
      super("SSRF blocked: #{@reason} (#{@ip}) for URL: #{@url}")
    end

    def message : String
      "SSRF blocked: #{@reason} (#{@ip}) for URL: #{@url}"
    end
  end

  struct Error
    include JSON::Serializable
    include YAML::Serializable

    getter type : ErrorType
    getter message : String
    getter context : Hash(String, String)?

    def initialize(@type : ErrorType, @message : String, @context : Hash(String, String)? = nil)
    end

    def self.file_not_found(path : String, message : String? = nil) : Error
      msg = message || "File not found"
      new(
        ErrorType::FileNotFound,
        "#{msg}: #{File.basename(path)}",
        {"path" => File.basename(path)}
      )
    end

    def self.invalid_image_path(path : String, reason : String? = nil) : Error
      msg = reason ? "Invalid image path: #{reason}" : "Invalid image path"
      new(
        ErrorType::InvalidImagePath,
        msg,
        {"path" => File.basename(path)}
      )
    end

    def self.unsupported_format(format : String) : Error
      new(
        ErrorType::UnsupportedFormat,
        "Unsupported image format: #{format}",
        {"format" => format}
      )
    end

    def self.corrupted_image(details : String? = nil) : Error
      msg = details ? "Corrupted or invalid image: #{details}" : "Corrupted or invalid image"
      new(ErrorType::CorruptedImage, msg)
    end

    def self.invalid_options(field : String, value : String, reason : String) : Error
      new(
        ErrorType::InvalidOptions,
        "Invalid #{field}: #{reason}",
        {"field" => field, "value" => value}
      )
    end

    def self.processing_failed(details : String) : Error
      new(ErrorType::ProcessingFailed, "Processing failed: #{details}")
    end

    def self.ssrf_blocked(url : String, ip : String, reason : String) : Error
      new(
        ErrorType::SSRFBlocked,
        "SSRF blocked: #{reason} (#{ip})",
        {"url" => url, "ip" => ip, "reason" => reason}
      )
    end

    def to_s(io : IO)
      io << "[#{@type}] #{@message}"
      if ctx = @context
        io << " ("
        ctx.each_with_index do |(k, v), i|
          io << ", " if i > 0
          io << "#{k}=#{v}"
        end
        io << ")"
      end
    end
  end
end
