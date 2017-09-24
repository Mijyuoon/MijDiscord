# frozen_string_literal: true

module MijDiscord::Data
  class Member < DelegateClass(User)
    include PermissionObject

    attr_reader :bot

    attr_reader :joined_at

    attr_reader :nickname
    alias_method :nick, :nickname

    attr_reader :roles

    attr_reader :server

    def mute?
      voice_state_attribute(:mute)
    end

    def deaf?
      voice_state_attribute(:deaf)
    end

    def self_mute?
      voice_state_attribute(:self_mute)
    end

    def self_deaf?
      voice_state_attribute(:self_deaf)
    end

    def voice_channel
      voice_state_attribute(:voice_channel)
    end

    def initialize(data, server, bot)
      @bot = bot

      @user = @bot.cache.put_user(data['user'])
      super @user

      raise ArgumentError, 'Cannot create member with no server' unless server || data['guild_id']
      @server = server || @bot.servers(data['guild_id'])

      @joined_at = Time.parse(data['joined_at']).utc if data['joined_at']

      update_data(data)
    end

    def update_data(data)
      @user.update_data(data['user'])

      @nickname = data.fetch('nick', @nickname || '')

      if (roles = data['roles'])
        @roles = roles.map {|x| @server.role(x) }
      end
    end

    def member?
      true
    end

    def owner?
      @server.owner == self
    end

    def role?(role)
      role = role.to_id
      @roles.any? {|x| x.id == role }
    end

    def set_roles(roles, reason = nil)
      roles = roles.map(&:to_id)
      MijDiscord::Core::API::Server.update_member(@bot.token, @server.id, @user.id, reason, roles: roles)
    end

    def modify_roles(add, remove, reason = nil)
      add, remove = add.map(&:to_id), remove.map(&:to_id)
      roles = (@roles.map(&:id) - remove + add).uniq
      MijDiscord::Core::API::Server.update_member(@bot.tolen, @server.id, @user.id, reason, roles: roles)
    end

    def add_role(role, reason = nil)
      if role.is_a?(Array)
        modify_roles(role, [], reason)
      else
        role = role.to_id
        MijDiscord::Core::API::Server.add_member_role(@bot.token, @server.id, @user.id, role, reason)
      end
    end

    def remove_role(role, reason = nil)
      if role.is_a?(Array)
        modify_roles([], role, reason)
      else
        role = role.to_id
        MijDiscord::Core::API::Server.remove_member_role(@bot.token, @server.id, @user.id, role, reason)
      end
    end

    def highest_role
      @roles.sort_by(&:position).last
    end

    def hoist_role
      roles = @roles.select(&:hoist)
      roles.sort_by(&:position).last
    end

    def color_role
      roles = @roles.select {|x| x.color.to_i.nonzero? }
      roles.sort_by(&:position).last
    end

    def color
      color_role&.color
    end

    def set_nickname(nick, reason = nil)
      nick ||= ''

      if @user.current_bot?
        MijDiscord::Core::API::User.change_own_nickname(@bot.token, @server.id, nick, reason)
      else
        MijDiscord::Core::API::Server.update_member(@bot.token, @server.id, @user.id, reason, nick: nick)
      end
    end

    alias_method :nickname=, :set_nickname

    def display_name
      nickname.empty? ? username : nickname
    end

    def inspect
      %(<Member user=#{@user.inspect} server=#{@server.id}>)
    end

    private

    def voice_state_attribute(key)
      @server.voice_states[@user.id]&.send(key)
    end
  end

  class Recipient < DelegateClass(User)
    attr_reader :joined_at

    attr_reader :nickname
    alias_method :nick, :nickname

    attr_reader :roles

    attr_reader :server

    def initialize(user, channel, bot)
      @bot, @channel, @user = bot, channel, user
      raise ArgumentError, 'Recipient for public channel' unless channel.private?

      super @user

      @mute = @deaf = @self_mute = @self_deaf = false
      @voice_channel, @server, @roles = nil, nil, []
      @nickname, @joined_at = '', @channel.creation_time
    end

    def inspect
      %(<Recipient user=#{@user.inspect} channel=#{@channel.inspect}>)
    end
  end
end