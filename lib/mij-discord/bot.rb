# frozen_string_literal: true

module MijDiscord
  class Bot
    class AuthInfo
      attr_reader :id

      attr_reader :token

      attr_reader :type

      attr_reader :name

      def initialize(id, token, type, name)
        @id, @type, @name = id.to_id, type, name

        @token = case type
          when :bot then "Bot #{token}"
          when :user then "#{token}"
          else raise ArgumentError, 'Invalid token type'
        end
      end

      def bot?
        @type == :bot
      end

      def user?
        @type == :user
      end

      alias_method :to_s, :token

      def inspect
        MijDiscord.make_inspect(self, :id, :type, :name)
      end
    end

    EVENTS = {
      ready: MijDiscord::Events::Ready,
      heartbeat: MijDiscord::Events::Heartbeat,
      connect: MijDiscord::Events::Connect,
      disconnect: MijDiscord::Events::Disconnect,
      exception: MijDiscord::Events::Exception,
      unhandled: MijDiscord::Events::Unhandled,

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
      update_webhooks: MijDiscord::Events::UpdateWebhooks,
      update_pins: MijDiscord::Events::UpdatePins,
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

    attr_reader :auth

    attr_reader :shard_key

    attr_reader :profile

    attr_reader :gateway

    attr_reader :cache

    def initialize(client_id:, token:, type: :bot, name: nil,
    shard_id: nil, num_shards: nil, ignore_bots: false, ignore_self: true)
      @auth = AuthInfo.new(client_id, token, type, name)

      @cache = MijDiscord::Cache::BotCache.new(self)

      @shard_key = [shard_id, num_shards] if num_shards
      @gateway = MijDiscord::Core::Gateway.new(self, @auth, @shard_key)

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
      raise 'Cannot get OAuth application for non-bot user' unless @auth.bot?

      response = MijDiscord::Core::API.oauth_application(@auth)
      MijDiscord::Data::Application.new(JSON.parse(response), self)
    end

    def invite(invite)
      code = parse_invite_code(invite)
      response = MijDiscord::Core::API::Invite.resolve(@auth, code, true)
      MijDiscord::Data::Invite.new(JSON.parse(response), self)
    end

    def accept_invite(invite)
      code = parse_invite_code(invite)
      MijDiscord::Core::API::Invite.accept(@auth, code)
      nil
    end

    def make_invite_url(server: nil, permissions: nil)
      url = "https://discordapp.com/oauth2/authorize?scope=bot&client_id=#{@auth.id}".dup
      url << "&permissions=#{permissions.to_i}" if permissions.respond_to?(:to_i)
      url << "&guild_id=#{server.to_id}" if server.respond_to?(:to_id)
      url
    end

    def create_server(name, region = 'eu-central')
      response = API::Server.create(@auth, name, region)
      id = JSON.parse(response)['id'].to_i

      loop do
        server = @cache.get_server(id, local: true)
        return server if server

        sleep(0.1)
      end
    end

    def parse_invite_code(invite)
      case invite
        when %r[^(?:https?://)?discord\.gg/(\w+)$]i then $1
        when %r[^https?://discordapp\.com/invite/(\w+)$]i then $1
        when %r[^([a-zA-Z0-9]+)$] then $1
        when MijDiscord::Data::Invite then invite.code
        else raise ArgumentError, 'Invalid invite format'
      end
    end

    def parse_mention(mention, server_id = nil)
      gateway_check

      case mention
        when /^<@!?(\d+)>$/
          server_id ? member(server_id, $1) : user($1)
        when /^<@&(\d+)>$/
          role = role(server_id, $1)
          return role if role

          servers.each do |sv|
            role = sv.role($1)
            return role if role
          end
        when /^<(a?):(\w+):(\d+)>$/
          emoji = emoji(server_id, $3)
          return emoji if emoji

          servers.each do |sv|
            emoji = sv.emoji($3)
            return emoji if emoji
          end

          em_data = { 'id' => $3.to_i, 'name' => $2, 'animated' => !$1.empty? }
          MijDiscord::Data::Emoji.new(em_data, nil)
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
      user = user.to_id

      return true if @ignore_self && user == @auth.id
      return true if @ignored_ids.include?(user)

      if @ignore_bots && (user = @cache.get_user(user, local: true))
        return true if user.bot_account?
      end

      false
    end

    def update_presence(status: nil, game: nil)
      gateway_check

      status = case status
        when nil then @profile.status
        when :online, :idle, :dnd, :online then status
        else raise ArgumentError, 'Invalid status'
      end

      game = case game
        when nil then @profile.game
        when false then nil
        when String, Hash
          MijDiscord::Data::Game.construct(game)
        when MijDiscord::Data::Game then game
        else raise ArgumentError, 'Invalid game'
      end&.to_hash

      @gateway.send_status_update(status, nil, game, false)
      @profile.update_presence('status' => status, 'game' => game)
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

        when :SESSIONS_REPLACE
          # Do nothing with session replace because no idea what it does.

        when :PRESENCES_REPLACE
          # Do nothing with presences replace because no idea what it does.

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

        when :GUILD_SYNC
          server = @cache.get_server(data['id'])
          server.update_synced_data(data)

        when :GUILD_UPDATE
          server = @cache.put_server(data, update: true)
          trigger_event(:update_server, self, server)

        when :GUILD_DELETE
          server = @cache.remove_server(data['id'])

          if data['unavailable'].eql?(true)
            MijDiscord::LOGGER.warn('Dispatch') { "Server <#{data['id']}> died due to outage" }
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

        when :WEBHOOKS_UPDATE
          channel = @cache.get_channel(data['channel_id'], nil)
          trigger_event(:update_webhooks, self, channel)

        when :CHANNEL_PINS_UPDATE
          channel = @cache.get_channel(data['channel_id'], nil)
          trigger_event(:update_pins, self, channel)

        when :CHANNEL_PINS_ACK
          # Do nothing with pins acknowledgement

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
          member = server.update_member(data, :add)
          trigger_event(:create_member, self, member, server)

        when :GUILD_MEMBER_UPDATE
          server = @cache.get_server(data['guild_id'])
          member = server.update_member(data, :update)
          trigger_event(:update_member, self, member, server)

        when :GUILD_MEMBER_REMOVE
          server = @cache.get_server(data['guild_id'])
          member = server.update_member(data, :remove)
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
          role = server.cache.remove_role(data['role_id'])
          trigger_event(:delete_role, self, server, role)

        when :GUILD_EMOJIS_UPDATE
          server = @cache.get_server(data['guild_id'])
          old_emojis = server.emojis
          server.update_emojis(data)
          trigger_event(:update_emoji, self, server, old_emojis, server.emojis)

        when :GUILD_BAN_ADD
          server = @cache.get_server(data['guild_id'])
          user = @cache.get_user(data['user']['id'], local: @auth.user?)
          user ||= MijDiscord::Data::User.new(data['user'], self)
          trigger_event(:ban_user, self, server, user)

        when :GUILD_BAN_REMOVE
          server = @cache.get_server(data['guild_id'])
          user = @cache.get_user(data['user']['id'], local: @auth.user?)
          user ||= MijDiscord::Data::User.new(data['user'], self)
          trigger_event(:unban_user, self, server, user)

        when :MESSAGE_CREATE
          channel = @cache.get_channel(data['channel_id'], nil)
          message = channel.cache.put_message(data)

          return if ignored_user?(data['author']['id'])
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

          channel = @cache.get_channel(data['channel_id'], nil)
          message = channel.cache.put_message(data, update: true)

          return if ignored_user?(author['id'])
          trigger_event(:edit_message, self, message)

        when :MESSAGE_DELETE
          channel = @cache.get_channel(data['channel_id'], nil)
          channel.cache.remove_message(data['id'])

          trigger_event(:delete_message, self, data)

        when :MESSAGE_DELETE_BULK
          messages = data['ids'].map {|x| {'id' => x, 'channel_id' => data['channel_id']} }
          messages.each {|x| trigger_event(:delete_message, self, x) }

        when :MESSAGE_REACTION_ADD
          channel = @cache.get_channel(data['channel_id'], nil)
          message = channel.cache.get_message(data['message_id'], local: true)
          message.update_reaction(add: data) if message

          return if ignored_user?(data['user_id'])
          trigger_event(:add_reaction, self, data)
          trigger_event(:toggle_reaction, self, data)

        when :MESSAGE_REACTION_REMOVE
          channel = @cache.get_channel(data['channel_id'], nil)
          message = channel.cache.get_message(data['message_id'], local: true)
          message.update_reaction(remove: data) if message

          return if ignored_user?(data['user_id'])
          trigger_event(:remove_reaction, self, data)
          trigger_event(:toggle_reaction, self, data)

        when :MESSAGE_REACTION_REMOVE_ALL
          channel = @cache.get_channel(data['channel_id'], nil)
          message = channel.cache.get_message(data['message_id'], local: true)
          message.update_reaction(clear: true) if message

          trigger_event(:clear_reactions, self, data)

        when :TYPING_START
          begin
            return if ignored_user?(data['user_id'])
            trigger_event(:start_typing, self, data)
          rescue MijDiscord::Errors::Forbidden
            # Ignoring the channel we can't access
            # Why is this even sent? :S
          end

        when :USER_UPDATE
          user = @cache.put_user(data, update: true)
          @profile.update_data(data) if user.id == @auth.id

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
          trigger_event(:unhandled, self, type, data)
      end
    rescue => exc
      MijDiscord::LOGGER.error('Dispatch') { 'An error occurred in dispatch handler' }
      MijDiscord::LOGGER.error('Dispatch') { exc }
    end

    def inspect
      MijDiscord.make_inspect(self, :auth)
    end

    private

    def gateway_check
      raise 'A gateway connection is required for this action' unless connected?
    end

    def notify_ready
      @gateway.notify_ready

      trigger_event(:ready, self)

      if @auth.user?
        guilds = @cache.list_servers.map(&:id)
        @gateway.send_request_guild_sync(guilds)
      end
    end

    def trigger_event(name, *args)
      @event_dispatchers[name]&.trigger(args)
    end
  end
end