module PrismatIQ
  module Version
    {% begin %}
      # Automatically derived from shard.yml at compile time
      VERSION = {{ `cat "#{__DIR__}/../../shard.yml" | grep -m1 "^version:" | cut -d' ' -f2`.strip.stringify }}
    {% end %}
  end
end
