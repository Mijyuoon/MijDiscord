# frozen_string_literal: true

module MijDiscord::Cache
  class BotCache
    def initialize(bot)
      @bot = bot

      reset
    end

    def reset
      @servers, @channels, @users = {}, {}, {}
      @pm_channels, @restricted_channels = {}, {}
    end

    def list_servers
      @servers.values
    end

    def list_channels
      @channels.values
    end

    def list_users
      @users.values
    end

    def get_server(key, local: false)
      id = key&.to_id || return
      return @servers[id] if @servers.has_key?(id)
      return nil if local

      begin
        response = MijDiscord::Core::API::Server.resolve(@bot.auth, id)
      rescue MijDiscord::Errors::NotFound
        return nil
      end

      @servers[id] = MijDiscord::Data::Server.new(JSON.parse(response), @bot)
    end

    def get_channel(key, server, local: false)
      id = key&.to_id || return
      return @channels[id] if @channels.has_key?(id)
      raise MijDiscord::Errors::Forbidden if @restricted_channels[id]
      return nil if local

      begin
        response = MijDiscord::Core::API::Channel.resolve(@bot.auth, id)
      rescue MijDiscord::Errors::NotFound
        return nil
      rescue MijDiscord::Errors::Forbidden
        @restricted_channels[id] = true
        raise
      end

      channel = @channels[id] = MijDiscord::Data::Channel.create(JSON.parse(response), @bot, server)
      @pm_channels[channel.recipient.id] = channel if channel.pm?

      if (server = channel.server)
        server.cache.put_channel!(channel)
      end

      channel
    end

    def get_pm_channel(key, local: false)
      id = key&.to_id || return
      return @pm_channels[id] if @pm_channels.has_key?(id)
      return nil if local

      response = MijDiscord::Core::API::User.create_pm(@bot.auth, id)
      channel = MijDiscord::Data::Channel.create(JSON.parse(response), @bot, nil)

      @channels[channel.id] = @pm_channels[id] = channel
    end

    def get_user(key, local: false)
      id = key&.to_id || return
      return @users[id] if @users.has_key?(id)
      return nil if local

      begin
        response = begin
          MijDiscord::Core::API::User.resolve(@bot.auth, id)
        rescue MijDiscord::Errors::Forbidden
          raise unless @bot.auth.user?
          MijDiscord::Core::API::User.resolve2(@bot.auth, id)
        end
      rescue MijDiscord::Errors::NotFound
        return nil
      end

      data = JSON.parse(response)
      if data['user'].is_a?(Hash)
        data = data['user']
      end

      @users[id] = MijDiscord::Data::User.new(data, @bot)
    end

    def put_server(data, update: false)
      id = data['id'].to_i
      if @servers.has_key?(id)
        @servers[id].update_data(data) if update
        return @servers[id]
      end

      @servers[id] = MijDiscord::Data::Server.new(data, @bot)
    end

    def put_channel(data, server, update: false)
      id = data['id'].to_i
      if @channels.has_key?(id)
        @channels[id].update_data(data) if update
        return @channels[id]
      end

      channel = @channels[id] = MijDiscord::Data::Channel.create(data, @bot, server)
      @pm_channels[channel.recipient.id] = channel if channel.pm?

      if (server = channel.server)
        server.cache.put_channel!(channel)
      end

      channel
    end

    def put_user(data, update: false)
      id = data['id'].to_i
      if @users.has_key?(id)
        @users[id].update_data(data) if update
        return @users[id]
      end

      @users[id] = MijDiscord::Data::User.new(data, @bot)
    end

    def remove_server(key)
      @servers.delete(key&.to_id)
    end

    def remove_channel(key)
      channel = @channels.delete(key&.to_id)
      @pm_channels.delete(channel.recipient.id) if channel&.pm?

      if (server = channel&.server)
        server.cache.remove_channel(key)
      end

      channel
    end

    def remove_user(key)
      @users.delete(key&.to_id)
    end

    def inspect
      MijDiscord.make_inspect(self)
    end
  end

  class ServerCache
    def initialize(server, bot)
      @server, @bot = server, bot

      reset
    end

    def reset
      @channels, @members, @roles = {}, {}, {}
    end

    def list_members
      @members.values
    end

    def list_roles
      @roles.values
    end

    def list_channels
      @channels.values
    end

    def get_member(key, local: false)
      id = key&.to_id || return
      return @members[id] if @members.has_key?(id)
      return nil if local

      begin
        response = MijDiscord::Core::API::Server.resolve_member(@bot.auth, @server.id, id)
      rescue MijDiscord::Errors::NotFound
        return nil
      end

      @members[id] = MijDiscord::Data::Member.new(JSON.parse(response), @server, @bot)
    end

    def get_role(key, local: false)
      id = key&.to_id || return
      return @roles[id] if @roles.has_key?(id)
      return nil if local

      # No API to get individual role
      nil
    end

    def get_channel(key, local: false)
      id = key&.to_id || return
      return @channels[id] if @channels.has_key?(id)

      channel = @bot.cache.get_channel(key, local: local)
      return nil unless channel&.server == @server

      @channels[channel.id] = channel
    end

    def put_member(data, update: false)
      id = data['user']['id'].to_i
      if @members.has_key?(id)
        @members[id].update_data(data) if update
        return @members[id]
      end

      @members[id] = MijDiscord::Data::Member.new(data, @server, @bot)
    end

    def put_role(data, update: false)
      id = data['id'].to_i
      if @roles.has_key?(id)
        @roles[id].update_data(data) if update
        return @roles[id]
      end

      @roles[id] = MijDiscord::Data::Role.new(data, @server, @bot)
    end

    def put_channel(data, update: false)
      channel = @bot.cache.put_channel(data, @server, update: update)
      @channels[channel.id] = channel
    end

    def put_channel!(channel)
      @channels[channel.id] = channel
    end

    def remove_member(key)
      @members.delete(key&.to_id)
    end

    def remove_role(key)
      @roles.delete(key&.to_id)
    end

    def remove_channel(key)
      channel = @channels.delete(key&.to_id)
      @bot.cache.remove_channel(key) if channel

      channel
    end

    def inspect
      MijDiscord.make_inspect(self)
    end
  end

  class ChannelCache
    MAX_MESSAGES = 200

    def initialize(channel, bot, max_messages: MAX_MESSAGES)
      @channel, @bot = channel, bot
      @max_messages = max_messages

      reset
    end

    def reset
      @messages = {}
    end

    def get_message(key, local: false)
      id = key&.to_id || return
      return @messages[id] if @messages.has_key?(id)
      return nil if local

      begin
        response = case @bot.auth.type
          when :bot then MijDiscord::Core::API::Channel.message(@bot.auth, @channel.id, key)
          when :user then MijDiscord::Core::API::Channel.messages(@bot.auth, @channel.id, 1, nil, nil, key)
        end
      rescue MijDiscord::Errors::NotFound
        return nil
      end

      data = JSON.parse(response)
      if data.is_a?(Array)
        data = data.first || return
      end

      message = @messages.store(id, MijDiscord::Data::Message.new(data, @bot))
      @messages.shift while @messages.length > @max_messages

      message
    end

    def put_message(data, update: false)
      id = data['id'].to_i
      if @messages.has_key?(id)
        @messages[id].update_data(data) if update
        return @messages[id]
      end

      message = @messages.store(id, MijDiscord::Data::Message.new(data, @bot))
      @messages.shift while @messages.length > @max_messages

      message
    end

    def remove_message(key)
      @messages.delete(key&.to_id)
    end

    def inspect
      MijDiscord.make_inspect(self)
    end
  end
end