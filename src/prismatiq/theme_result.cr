require "json"

module PrismatIQ
  struct ThemeResult
    getter bg : String
    getter text : Hash(String, String)

    def initialize(@bg : String, @text : Hash(String, String))
    end

    def initialize(bg_rgb : Array(Int32), text_light : String, text_dark : String)
      @bg = "rgb(#{bg_rgb[0]}, #{bg_rgb[1]}, #{bg_rgb[2]})"
      @text = {"light" => text_light, "dark" => text_dark}
    end

    def to_json : String
      {"bg" => @bg, "text" => @text}.to_json
    end

    def self.from_json(json_str : String) : ThemeResult?
      parsed = JSON.parse(json_str)
      bg = parsed["bg"].as_s
      text_hash = {} of String => String
      parsed["text"].as_h.each do |k, v|
        text_hash[k] = v.as_s
      end
      new(bg, text_hash)
    rescue
      nil
    end
  end
end
