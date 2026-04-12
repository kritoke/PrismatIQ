require "json"

module PrismatIQ
  struct ThemeResult
    include JSON::Serializable

    getter bg : String
    getter text : Hash(String, String)

    def initialize(@bg : String, @text : Hash(String, String))
    end

    def initialize(bg_rgb : Array(Int32), text_light : String, text_dark : String)
      @bg = "rgb(#{bg_rgb[0]}, #{bg_rgb[1]}, #{bg_rgb[2]})"
      @text = {"light" => text_light, "dark" => text_dark}
    end

    def self.from_json_string(json_str : String) : ThemeResult?
      ThemeResult.from_json(json_str)
    rescue
      nil
    end
  end
end
