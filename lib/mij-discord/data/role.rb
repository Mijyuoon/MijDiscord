# frozen_string_literal: true

module MijDiscord::Data
  class Role
    include IDObject

    attr_reader :permissions

    attr_reader :name

    attr_reader :hoist

    attr_reader :managed
    alias_method :managed?, :managed

    attr_reader :mentionable
    alias_method :mentionable?, :mentionable

    attr_reader :color

    attr_reader :position

    def initialize(data, server, bot)
      @bot, @server = bot, server

      @permissions = Permissions.new
      @color = ColorRGB.new

      @id = data['id'].to_i
      update_data(data)
    end

    def update_data(data)
      @name = data.fetch('name', @name)
      @position = data.fetch('position', @position)
      @hoist = data.fetch('hoist', @hoist)
      @mentionable = data.fetch('mentionable', @mentionable)
      @managed = data.fetch('managed', @managed)

      @color.value = data.fetch('color', @color.value)

      if (bits = data['permissions'])
        @permissions.bits = bits.to_i
      end
    end

    def mention
      "<@&#{@id}>"
    end

    alias_method :to_s, :mention

    def members
      @server.members.select {|x| x.role?(self) }
    end

    alias_method :users, :members

    def set_name(name)
      set_options(name: name)
    end

    alias_method :name=, :set_name

    def set_hoist(flag)
      set_options(hoist: flag)
    end
    
    alias_method :hoist=, :set_hoist

    def set_mentionable(flag)
      set_options(mentionable: flag)
    end

    alias_method :mentionable=, :set_mentionable

    def set_color(color)
      set_options(color: color)
    end

    alias_method :color=, :set_color

    def delete(reason = nil)
      MijDiscord::Core::API::Server.delete_role(@bot.token, @server.id, @id, reason)
    end

    def set_options(name: nil, color: nil, hoist: nil, mentionable: nil, permissions: nil)
      response = MijDiscord::Core::API::Server.update_role(@bot.token, @server.id, @id,
        name, color&.to_i, hoist, mentionable, permissions&.to_i)
      @server.cache.put_role(JSON.parse(response), update: true)
    end

    def inspect
      %(<Role id=#{@id} name=#{@name} server=#{@server.inspect}>)
    end

    private
  end
end