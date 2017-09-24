# frozen_string_literal: true

module MijDiscord
  class Bot
    EVENTS = {
      ready: MijDiscord::Events::Ready,
      heartbeat: MijDiscord::Events::Heartbeat,
      connect: MijDiscord::Events::Connect,
      disconnect: MijDiscord::Events::Disconnect,
      exception: MijDiscord::Events::Exception,

      update_user: MijDiscord::Events::UpdateUser,
      create_server: MijDiscord::Events::CreateServer,
      update_server: MijDiscord::Events::UpdateServer,
      delete_server: MijDiscord::Events::DeleteServer,
      update_emoji: MijDiscord::Events::UpdateEmoji,
      ban_user: MijDiscord::Events::BanUser,
      unban_user: MijDiscord::Events::UnbanUser,

      create_role: MijDiscord::Events::CreateRole,
      update_role: MijDiscord::Events::UpdateRole,
      delete_role: MijDiscord::Events::DeleteRole,
      create_member: MijDiscord::Events::CreateMember,
      update_member: MijDiscord::Events::UpdateMember,
      delete_member: MijDiscord::Events::DeleteMember,

      create_channel: MijDiscord::Events::CreateChannel,
      update_channel: MijDiscord::Events::UpdateChannel,
      delete_channel: MijDiscord::Events::DeleteChannel,
      add_recipient: MijDiscord::Events::AddRecipient,
      remove_recipient: MijDiscord::Events::RemoveRecipient,

      create_message: MijDiscord::Events::CreateMessage,
      channel_message: MijDiscord::Events::ChannelMessage,
      private_message: MijDiscord::Events::PrivateMessage,
      edit_message: MijDiscord::Events::EditMessage,
      delete_message: MijDiscord::Events::DeleteMessage,
      add_reaction: MijDiscord::Events::AddReaction,
      remove_reaction: MijDiscord::Events::RemoveReaction,
      toggle_reaction: MijDiscord::Events::ToggleReaction,
      clear_reactions: MijDiscord::Events::ClearReactions,
      start_typing: MijDiscord::Events::StartTyping,

      update_presence: MijDiscord::Events::UpdatePresence,
      update_playing: MijDiscord::Events::UpdatePlaying,
      update_voice_state: MijDiscord::Events::UpdateVoiceState,
    }.freeze

    UNAVAILABLE_SERVER_TIMEOUT = 10

    USER_STATUS = {
      online: :online,
      idle: :idle,
      away: :idle,
      dnd: :dnd,
      busy: :dnd,
      invisible: :invisible,
      hidden: :invisible,
      offline: :offline
    }.freeze

    attr_reader :name

    attr_reader :type

    attr_reader :client_id

    attr_reader :token

    attr_reader :shard_key

    attr_reader :profile

    attr_reader :gateway

    attr_reader :cache

    def initialize(client_id:, token:, type: :bot, name: nil,
    shard_id: nil, num_shards: nil, ignore_bots: false, ignore_self: true)
      @client_id, @type, @name = client_id.to_id, type, name || ''

      @token = case @type
        when :bot then "Bot #{token}"
        when :user then "#{token}"
        else raise ArgumentError, 'Invalid bot type'
      end

      @cache = MijDiscord::Cache::BotCache.new(self)

      @shard_key = [shard_id, num_shards] if num_shards
      @gateway = MijDiscord::Core::Gateway.new(self, @token, @shard_key)

      @ignore_bots, @ignore_self, @ignored_ids = ignore_bots, ignore_self, Set.new

      @unavailable_servers = 0

      @event_dispatchers = {}
    end

    def connect(async = true)
      @gateway.run_async
      @gateway.sync unless async
      nil
    end

    def sync
      @gateway.sync
      nil
    end

    def disconnect(no_sync = false)
      @gateway.stop(no_sync)
      nil
    end

    alias_method :shutdown, :disconnect

    def connected?
      @gateway.open?
    end

    def servers
      gateway_check
      @cache.list_servers
    end

    def server(id)
      gateway_check
      @cache.get_server(id)
    end

    def channels
      gateway_check
      @cache.list_channels
    end

    def channel(id, server = nil)
      gateway_check
      @cache.get_channel(id, server)
    end

    def pm_channel(id)
      gateway_check
      @cache.get_pm_channel(id)
    end

    alias_method :dm_channel, :pm_channel

    def users
      gateway_check
      @cache.list_users
    end

    def user(id)
      gateway_check
      @cache.get_user(id)
    end

    def members(server_id)
      gateway_check
      server(server_id)&.members
    end

    def member(server_id, id)
      gateway_check
      server(server_id)&.member(id)
    end

    def roles(server_id)
      gateway_check
      server(server_id)&.roles
    end

    def role(server_id, id)
      gateway_check
      server(server_id)&.role(id)
    end

    def emojis(server_id)
      gateway_check
      server(server_id)&.emojis
    end

    def emoji(server_id, id)
      gateway_check
      server(server_id)&.emoji(id)
    end

    def application
      raise RuntimeError, 'Cannot get OAuth application for non-bot user' if @type != :bot

      response = MijDiscord::Core::API.oauth_application(@token)
      MijDiscord::Data::Application.new(JSON.parse(response), self)
    end

    def invite(invite)
      code = parse_invite_code(invite)
      response = MijDiscord::Core::API::Invite.resolve(token, code)
      MijDiscord::Data::Invite.new(JSON.parse(response), self)
    end

    def accept_invite(invite)
      code = parse_invite_code(invite)
      API::Invite.accept(token, code)
      nil
    end

    def make_invite_url(server: nil, permissions: nil)
      url = "https://discordapp.com/oauth2/authorize?scope=bot&client_id=#{@client_id}".dup
      url << "&permissions=#{permissions.to_i}" if permissions.respond_to?(:to_i)
      url << "&guild_id=#{server.to_id}" if server.respond_to?(:to_id)
      url
    end

    def create_server(name, region = 'eu-central')
      response = API::Server.create(@token, name, region)
      id = JSON.parse(response)['id'].to_i

      loop do
        server = @cache.get_server(id, local: true)
        return server if server

        sleep(0.1)
      end
    end

    def parse_invite_code(invite)
      case invite
        when %r[(\w+)] then $1
        when %r[(?:https?://)?discord\.gg/(\w+)]i then $1
        when %r[https?://discordapp\.com/invite/(\w+)]i then $1
        when MijDiscord::Data::Invite then invite.code
        else raise ArgumentError, 'Invalid invite format'
      end
    end

    def parse_mention(mention, server_id = nil)
      gateway_check

      case mention
        when /<@!?(\d+)>/
          server_id ? member(server_id, $1) : user($1)
        when /<@&(\d+)>/
          role = role(server_id, $1)
          return role if role

          servers.each do |sv|
            role = sv.role($1)
            return role if role
          end
        when /<:\w+:(\d+)>/
          emoji = emoji(server_id, $1)
          return emoji if emoji

          servers.each do |sv|
            emoji = sv.emoji($1)
            return emoji if emoji
          end
      end
    end

    def add_event(type, key = nil, **filter, &block)
      raise ArgumentError, "Invalid event type: #{type}" unless EVENTS[type]

      event = (@event_dispatchers[type] ||= MijDiscord::Events::EventDispatcher.new(EVENTS[type], self))
      event.add_callback(key, filter, &block)
    end

    def remove_event(type, key)
      raise ArgumentError, "Invalid event type: #{type}" unless EVENTS[type]

      @event_dispatchers[type]&.remove_callback(key)
      nil
    end

    def events(type)
      raise ArgumentError, "Invalid event type: #{type}" unless EVENTS[type]

      @event_dispatchers[type]&.callbacks || []
    end

    def ignore_user(user)
      @ignored_ids << user.to_id
      nil
    end

    def unignore_user(user)
      @ignored_ids.delete(user.to_id)
      nil
    end

    def ignored_user?(user)
      @ignore_self && user.to_id == @client_id || @ignored_ids.include?(user.to_id)
    end

    def change_status(status: nil, game: nil, url: nil)
      gateway_check

      status = status.nil? ? @profile.status : USER_STATUS[status]
      raise ArgumentError, "Status '#{status}' is not valid" unless status

      game_obj = case game
        when false
          nil
        when nil
          {'name' => @profile.game, 'url' => @profile.stream_url, 'type' => @profile.stream_type}
        else
          {'name' => game, 'url' => url, 'type' => url ? 1 : 0}
      end

      game_obj&.reject! {|_,v| v.nil? }
      game_obj = nil if game_obj&.empty?

      @gateway.send_status_update(status, nil, game_obj, false)
      @profile.update_presence('status' => status, 'game' => game_obj)
      nil
    end

    def handle_heartbeat
      trigger_event(:heartbeat, self)
    end

    def handle_exception(type, exception, payload = nil)
      return if type == :event && payload&.is_a?(MijDiscord::Events::Exception)

      trigger_event(:exception, self, type, exception, payload)
    end

    def handle_dispatch(type, data)
      MijDiscord::LOGGER.debug('Dispatch') { "<#{type} #{data.inspect}>" }

      if @unavailable_servers > 0 && Time.now > @unavailable_servers_timeout
        MijDiscord::LOGGER.warn('Dispatch') { "Proceeding with #{@unavailable_servers} servers still unavailable" }

        @unavailable_servers = 0
        notify_ready
      end

      case type
        when :CONNECT
          trigger_event(:connect, self)

        when :DISCONNECT
          trigger_event(:disconnect, self)

        when :READY
          @cache.reset

          @profile = MijDiscord::Data::Profile.new(data['user'], self)
          @profile.update_presence('status' => :online)

          @unavailable_servers = 0
          @unavailable_servers_timeout = Time.now + UNAVAILABLE_SERVER_TIMEOUT

          data['guilds'].each do |sv|
            if sv['unavailable'].eql?(true)
              @unavailable_servers += 1
            else
              @cache.put_server(sv)
            end
          end

          data['private_channels'].each do |ch|
            @cache.put_channel(ch, nil)
          end

          notify_ready if @unavailable_servers.zero?

        when :GUILD_MEMBERS_CHUNK
          server = @cache.get_server(data['guild_id'])
          server.update_members_chunk(data['members'])

        when :GUILD_CREATE
          server = @cache.put_server(data)

          if data['unavailable'].eql?(false)
            @unavailable_servers -= 1
            @unavailable_servers_timeout = Time.now + UNAVAILABLE_SERVER_TIMEOUT

            notify_ready if @unavailable_servers.zero?
            return
          end

          trigger_event(:create_server, self, server)

        when :GUILD_UPDATE
          server = @cache.put_server(data, update: true)
          trigger_event(:update_server, self, server)

        when :GUILD_DELETE
          server = @cache.remove_server(data['id'])

          if data['unavailable'].eql?(true)
            MijDiscord::LOGGER.warn('Dispatch') { "Server <#{server.id}> died due to outage" }
            return
          end

          trigger_event(:delete_server, self, server)

        when :CHANNEL_CREATE
          channel = @cache.put_channel(data, nil)
          trigger_event(:create_channel, self, channel)

        when :CHANNEL_UPDATE
          channel = @cache.put_channel(data, nil, update: true)
          trigger_event(:update_channel, self, channel)

        when :CHANNEL_DELETE
          channel = @cache.remove_channel(data['id'])
          trigger_event(:delete_channel, self, channel)

        when :CHANNEL_RECIPIENT_ADD
          channel = @cache.get_channel(data['channel_id'], nil)
          recipient = channel.update_recipient(add: data['user'])
          trigger_event(:add_recipient, self, channel, recipient)

        when :CHANNEL_RECIPIENT_REMOVE
          channel = @cache.get_channel(data['channel_id'], nil)
          recipient = channel.update_recipient(remove: data['user'])
          trigger_event(:remove_recipient, self, channel, recipient)

        when :GUILD_MEMBER_ADD
          server = @cache.get_server(data['guild_id'])
          member = server.cache.put_member(data)
          trigger_event(:create_member, self, member, server)

        when :GUILD_MEMBER_UPDATE
          server = @cache.get_server(data['guild_id'])
          member = server.cache.put_member(data, update: true)
          trigger_event(:update_member, self, member, server)

        when :GUILD_MEMBER_REMOVE
          server = @cache.get_server(data['guild_id'])
          member = server.cache.remove_member(data['user']['id'])
          trigger_event(:delete_member, self, member, server)

        when :GUILD_ROLE_CREATE
          server = @cache.get_server(data['guild_id'])
          role = server.cache.put_role(data['role'])
          trigger_event(:create_role, self, server, role)

        when :GUILD_ROLE_UPDATE
          server = @cache.get_server(data['guild_id'])
          role = server.cache.put_role(data['role'], update: true)
          trigger_event(:update_role, self, server, role)

        when :GUILD_ROLE_DELETE
          server = @cache.get_server(data['guild_id'])
          role = server.cache.remove_role(data['role']['id'])
          trigger_event(:delete_role, self, server, role)

        when :GUILD_EMOJIS_UPDATE
          server = @cache.get_server(data['guild_id'])
          old_emojis = server.emojis
          server.update_emojis(data)
          trigger_event(:update_emoji, self, server, old_emojis, server.emojis)

        when :GUILD_BAN_ADD
          server = @cache.get_server(data['guild_id'])
          user = @cache.get_user(data['user']['id'])
          trigger_event(:ban_user, self, server, user)

        when :GUILD_BAN_REMOVE
          server = @cache.get_server(data['guild_id'])
          user = @cache.get_user(data['user']['id'])
          trigger_event(:unban_user, self, server, user)

        when :MESSAGE_CREATE
          return if ignored_user?(data['author']['id'])
          return if @ignore_bots && data['author']['bot']

          channel = @cache.get_channel(data['channel_id'], nil)
          message = channel.cache.put_message(data)
          trigger_event(:create_message, self, message)

          if message.channel.private?
            trigger_event(:private_message, self, message)
          else
            trigger_event(:channel_message, self, message)
          end

        when :MESSAGE_ACK
          # Do nothing with message acknowledgement

        when :MESSAGE_UPDATE
          author = data['author']
          return if author.nil?

          return if ignored_user?(author['id'])
          return if @ignore_bots && author['bot']

          channel = @cache.get_channel(data['channel_id'], nil)
          message = channel.cache.put_message(data, update: true)
          trigger_event(:edit_message, self, message)

        when :MESSAGE_DELETE
          channel = @cache.get_channel(data['channel_id'], nil)
          channel.cache.remove_message(data['id'])

          trigger_event(:delete_message, self, data)

        when :MESSAGE_DELETE_BULK
          messages = data['ids'].map {|x| {'id' => x, 'channel_id' => data['channel_id']} }
          messages.each {|x| trigger_event(:delete_message, self, x) }

        when :MESSAGE_REACTION_ADD
          # Should add full use ignore support?
          return if ignored_user?(data['user_id'])

          trigger_event(:add_reaction, self, data)
          trigger_event(:toggle_reaction, self, data)

        when :MESSAGE_REACTION_REMOVE
          # Should add full use ignore support?
          return if ignored_user?(data['user_id'])

          trigger_event(:remove_reaction, self, data)
          trigger_event(:toggle_reaction, self, data)

        when :MESSAGE_REACTION_REMOVE_ALL
          trigger_event(:clear_reactions, self, data)

        when :TYPING_START
          begin
            trigger_event(:start_typing, self, data)
          rescue MijDiscord::Core::Errors::NoPermission
            # Ignoring the channel we can't access
            # Why is this even sent? :S
          end

        when :USER_UPDATE
          user = @cache.put_user(data, update: true)
          trigger_event(:update_user, self, user)

        when :PRESENCE_UPDATE
          return unless data['guild_id']

          server = @cache.get_server(data['guild_id'])
          member = server.cache.put_member(data, update: true)

          old_game = member.game
          member.update_presence(data)

          if old_game != member.game
            trigger_event(:update_playing, self, data)
          else
            trigger_event(:update_presence, self, data)
          end

        when :VOICE_STATE_UPDATE
          server = @cache.get_server(data['guild_id'])
          state = server.update_voice_state(data)
          trigger_event(:update_voice_state, self, state)

        else
          MijDiscord::LOGGER.warn('Dispatch') { "Unhandled gateway event type: #{type}" }
      end
    rescue => exc
      MijDiscord::LOGGER.error('Dispatch') { 'An error occurred in dispatch handler' }
      MijDiscord::LOGGER.error('Dispatch') { exc }
    end

    private

    def gateway_check
      raise RuntimeError, 'A gateway connection is required for this action' unless connected?
    end

    def notify_ready
      @gateway.notify_ready

      trigger_event(:ready, self)
    end

    def trigger_event(name, *args)
      @event_dispatchers[name]&.trigger(args)
    end
  end
end