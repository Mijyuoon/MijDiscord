# frozen_string_literal: true

module MijDiscord::Data
  DISCORD_EPOCH = 1_420_070_400_000

  CHARACTER_LIMIT = 2000

  module IDObject
    attr_reader :id
    alias_method :to_id, :id

    def hash
      @id.hash
    end

    def ==(other)
      @id == (other.respond_to?(:to_id) ? other.to_id : other)
    end

    alias_method :eql?, :==

    def creation_time
      ms = (@id >> 22) + DISCORD_EPOCH
      Time.at(ms / 1000.0).utc
    end

    def self.synthesize(time)
      ms = (time.to_f * 1000).to_i
      (ms - DISCORD_EPOCH) << 22
    end
  end

  module PermissionObject

  end

  class ColorRGB
    attr_reader :red
    alias_method :r, :red

    attr_reader :green
    alias_method :g, :green

    attr_reader :blue
    alias_method :b, :blue

    attr_reader :value
    alias_method :to_i, :value

    def initialize(color = nil)
      self.value = color || 0xFFFFFF
    end

    def value=(color)
      @value = color.is_a?(String) ? color.to_i(16) : color
      @red = (@value >> 16) & 0xFF
      @green = (@value >> 8) & 0xFF
      @blue = (@value >> 0) & 0xFF
    end

    def to_hex
      '%06x' % @value
    end
  end
end