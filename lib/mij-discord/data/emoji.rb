# frozen_string_literal: true

module MijDiscord::Data
  class Emoji
    include IDObject

    attr_reader :name

    attr_reader :server

    attr_reader :roles

    attr_reader :animated

    def initialize(data, server)
      @server = server

      @id = data['id'].to_i
      @name = data['name']
      @animated = !!data['animated']

      @roles = []
      if @server && (roles = data['roles'])
        @roles = roles.map {|ro| @server.role(ro) }
      end
    end

    def mention
      a = @animated ? 'a' : ''
      "<#{a}:#{@name}:#{@id}>"
    end

    alias_method :to_s, :mention

    def reaction
      @id.zero? ? @name : "#{@name}:#{@id}"
    end

    def icon_url(format = nil)
      format = @animated ? :gif : :png if format.nil?
      MijDiscord::Core::API.emoji_icon_url(@id, format)
    end

    def inspect
      MijDiscord.make_inspect(self, :id, :name, :animated)
    end
  end

  class Reaction < Emoji
    attr_reader :message

    attr_reader :count

    attr_reader :me
    alias_method :me?, :me

    def initialize(data, message)
      super(data['emoji'], nil)

      @message = message

      @me = !!data['me']
      @count = data['count'] || 1
    end

    def update_data(count: nil, me: nil)
      @count = count unless count.nil?
      @me = me unless me.nil?
    end

    def inspect
      MijDiscord.make_inspect(self, :id, :name, :count, :me)
    end
  end
end