require "json"

module PrismatIQ
  struct ThemeResult
    include JSON::Serializable

    getter bg : String
    getter text : Hash(String, String)

    def initialize(@bg : String, @text : Hash(String, String))
    end

    def initialize(bg_rgb : RGB, text_light : String, text_dark : String)
      @bg = "rgb(#{bg_rgb.r}, #{bg_rgb.g}, #{bg_rgb.b})"
      @text = {"light" => text_light, "dark" => text_dark}
    end

    def self.from_json_string(json_str : String) : ThemeResult?
      ThemeResult.from_json(json_str)
    rescue JSON::ParseException
      nil
    end
  end
end
