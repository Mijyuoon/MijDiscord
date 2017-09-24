# frozen_string_literal: true

module MijDiscord::Data
  class Emoji
    include IDObject

    attr_reader :name

    attr_reader :server

    attr_reader :roles

    def initialize(data, bot, server)
      @bot, @server = bot, server

      @id = data['id'].to_i
      @name = data['name']

      @roles = []
      if @server && (roles = data['roles'])
        @roles = roles.map {|ro| @server.role(ro) }
      end
    end

    def mention
      "<:#{@name}:#{@id}>"
    end

    alias_method :to_s, :mention

    def reaction
      @id.zero? ? @name : "#{@name}:#{@id}"
    end

    def icon_url(format = :png)
      MijDiscord::Core::API.emoji_icon_url(@id, format)
    end

    def inspect
      %(<Emoji id=#{@id} name=#{@name}>)
    end
  end

  class Reaction
    attr_reader :id

    attr_reader :name

    attr_reader :count

    attr_reader :me
    alias_method :me?, :me

    def initialize(data)
      @me = !!data['me']
      @count = data['count'] || 1

      @id = data['emoji']['id']&.to_i
      @name = data['emoji']['name']
    end
  end
end