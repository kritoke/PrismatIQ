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
  end

  struct Error
    include JSON::Serializable
    include YAML::Serializable

    getter type : ErrorType
    getter message : String
    getter context : Hash(String, String)?

    def initialize(@type : ErrorType, @message : String, @context : Hash(String, String)? = nil)
    end

    def self.file_not_found(path : String) : Error
      new(
        ErrorType::FileNotFound,
        "File not found: #{File.basename(path)}",
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

    def to_json(builder : JSON::Builder)
      builder.start_object
      builder.field("type", @type.to_s)
      builder.field("message", @message)
      if @context
        builder.field("context")
        @context.each do |k, v|
          builder.field(k, v)
        end
      end
      builder.end_object
    end

    def to_yaml(yaml : YAML::Nodes::Builder)
      yaml.scalar "#{@type}: #{@message}"
    end

    def self.new(pull : JSON::PullParser)
      type = pull.read_string
      from_json(type)
    end

    def self.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
      unless node.is_a?(YAML::Nodes::Scalar)
        raise ValidationError.new("Expected scalar for Error")
      end
      from_json(node.value)
    end
  end
end


  struct Error
    getter type : ErrorType
    getter message : String
    getter context : Hash(String, String)?

    def initialize(@type : ErrorType, @message : String, @context : Hash(String, String)? = nil)
    end

    def self.file_not_found(path : String) : Error
      new(
        ErrorType::FileNotFound,
        "File not found: #{File.basename(path)}",
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
