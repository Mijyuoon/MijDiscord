# frozen_string_literal: true

module MijDiscord::Errors
  class DiscordError < RuntimeError
    attr_reader :code

    attr_reader :response

    def initialize(code, message, response)
      super(message || "(Error #{code})")

      @code, @response = code, response
    end
  end

  class MessageTooLong < DiscordError
    MATCH_PATTERNS = [['2000'], ['long', 'length', 'size'], ['fewer', 'maximum']]

    # This is shitcode
    def self.match_pattern?(error)
      return false if error.nil?
      MATCH_PATTERNS.reduce(true) {|a,x| a && x.reduce(false) {|b,y| b || error.include?(y) } }
    end

    def initialize(message, response)
      super(nil, message, response)
    end
  end

  class Unauthorized < DiscordError; end

  class Forbidden < DiscordError; end

  class BadRequest < DiscordError; end

  class NotFound < DiscordError; end

  HTTP_ERRORS = {
    400 => BadRequest,
    401 => Unauthorized,
    403 => Forbidden,
    404 => NotFound,
  }.freeze
end