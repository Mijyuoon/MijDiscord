# frozen_string_literal: true

module MijDiscord::Data
  class Server
    VERIFICATION_LEVEL = {
      0 => :none,
      1 => :low,
      2 => :medium,
      3 => :high,
      4 => :very_high,
    }.freeze

    CONTENT_FILTER_LEVEL = {
      0 => :none,
      1 => :no_roles,
      2 => :all,
    }.freeze

    DEFAULT_NOTIFICATIONS = {
      0 => :all,
      1 => :mentions,
    }.freeze

    CHANNEL_TYPES = {
      :text     => 0,
      :voice    => 2,
      :category => 4,
    }.freeze

    include IDObject

    attr_reader :bot

    attr_reader :name

    attr_reader :icon_id

    attr_reader :owner

    attr_reader :large
    alias_method :large?, :large

    attr_reader :features
    
    attr_reader :embed_enabled
    alias_method :embed_enabled?, :embed_enabled
    alias_method :has_embed?, :embed_enabled

    attr_reader :member_count

    attr_reader :verification_level

    attr_reader :content_filter_level
    alias_method :content_filter, :content_filter_level

    attr_reader :default_notifications

    attr_reader :afk_timeout

    attr_reader :afk_channel

    attr_reader :cache

    def initialize(data, bot, invalid = false)
      @bot = bot

      @id = data['id'].to_i
      @large = data['large']
      @member_count = data['member_count']

      @cache = MijDiscord::Cache::ServerCache.new(self, @bot)

      data['channels']&.each {|ch| @cache.put_channel(ch) }

      data['roles']&.each {|ro| @cache.put_role(ro) }

      update_synced_data(data)

      @voice_states = {}
      data['voice_states']&.each {|vs| update_voice_state(vs) }

      update_emojis(data)
      update_data(data)

      @owner = member(data['owner_id'])
    end

    def update_data(data)
      @name = data.fetch('name', @name)
      @region_id = data.fetch('region', @region_id)
      @icon_id = data.fetch('icon', @icon_id)
      @afk_timeout = data.fetch('afk_timeout', @afk_timeout)
      @embed_enabled = data.fetch('embed_enabled', @embed_enabled)
      @verification_level = VERIFICATION_LEVEL.fetch(data['verification_level'], @verification_level)
      @content_filter_level = CONTENT_FILTER_LEVEL.fetch(data['explicit_content_filter'], @content_filter_level)
      @default_notifications = DEFAULT_NOTIFICATIONS.fetch(data['default_message_notifications'], @default_notifications)

      begin
        if data.has_key?('afk_channel_id')
          id = data['afk_channel_id'].to_i
          @afk_channel = @bot.channel(id, self)
        end
      rescue MijDiscord::Errors::Forbidden
        @afk_channel = nil
      end
    end

    def update_emojis(data)
      if (emojis = data['emojis'])
        @emojis = emojis.each_with_object({}) do |el, p|
          p[el['id'].to_i] = Emoji.new(el, self)
        end
      end
      @emojis ||= {}
    end

    def update_voice_state(data)
      user = @cache.get_member(data['user_id'])

      if (chan_id = data['channel_id']&.to_i)
        state = (@voice_states[user.id] ||= VoiceState.new(user))
        channel = @cache.get_channel(chan_id)

        state.update_data(channel, data) if channel
        state
      else
        state = @voice_states.delete(user.id)
        state ||= VoiceState.new(user)

        state.update_data(nil, data)
        state
      end
    end

    def update_members_chunk(data)
      return if @members_chunked.nil?

      @members_chunked += data.length
      data.each {|mb| @cache.put_member(mb, update: true) }

      @members_chunked = nil if @members_chunked == @member_count
    end

    def update_synced_data(data)
      data['members']&.each {|mb| @cache.put_member(mb, update: true) }

      data['presences']&.each do |pr|
        next unless pr['user']

        user_id = pr['user']['id'].to_i
        user = @cache.get_member(user_id, local: true)
        user.update_presence(pr) if user
      end
    end

    def update_member(data, mode)
      case mode
        when :add
          @member_count += 1
          @cache.put_member(data)
        when :remove
          @member_count -= 1
          key = data['user']['id']
          @cache.remove_member(key)
        when :update
          @cache.put_member(data, update: true)
      end
    end

    def channels
      @cache.list_channels
    end

    def channel(id)
      @cache.get_channel(id)
    end

    def roles
      @cache.list_roles
    end

    def role(id)
      @cache.get_role(id)
    end

    def members(full = false)
      if full && !@members_chunk_sent
        @members_chunked, @members_chunk_sent = 0, true
        @bot.gateway.send_request_members(@id, '', 0)
      end

      sleep(0.05) while @members_chunked

      @cache.list_members
    end

    def member(id)
      @cache.get_member(id)
    end

    def emojis
      @emojis.values
    end

    def emoji(id)
      @emojis[id&.to_id]
    end

    def everyone_role
      role(@id)
    end

    def voice_states
      @voice_states.values
    end

    def voice_state(id)
      @voice_states[id&.to_id]
    end

    def default_channel(can_send = false)
      text_channels.sort_by {|ch| [ch.position, ch.id] }.find do |ch|
        if (overwrite = ch.permission_overwrites[id])
          if can_send
            overwrite.allow.send_messages? || !overwrite.deny.send_messages?
          else
            overwrite.allow.read_messages? || !overwrite.deny.read_messages?
          end
        else
          if can_send
            everyone_role.permissions.send_messages
          else
            everyone_role.permissions.read_messages
          end
        end
      end
    end

    alias_method :general_channel, :default_channel

    def online_members(idle: true, bots: false)
      members.select! do |m|
        ((idle ? m.idle? : false) || m.online?) && (bots ? true : !m.bot_account?)
      end
    end

    def invites
      response = MijDiscord::Core::API::Server.invites(@bot.auth, @id)
      JSON.parse(response).map {|x| Invite.new(x, @bot) }
    end

    def webhooks
      response = MijDiscord::Core::API::Server.webhooks(@bot.auth, @id)
      JSON.parse(response).map {|x| Webhook.new(x, @bot) }
    end

    def prune_count(days)
      raise ArgumentError, 'Days must be between 1 and 30' unless days.between?(1, 30)

      response = MijDiscord::Core::API::Server.prune_count(@bot.auth, @id, days)
      JSON.parse(response)['pruned']
    end

    def prune(days, reason = nil)
      raise ArgumentError, 'Days must be between 1 and 30' unless days.between?(1, 30)

      response = MijDiscord::Core::API::Server.begin_prune(@bot.auth, @id, days, reason)
      JSON.parse(response)['pruned']
    end

    def text_channels
      channels.select!(&:text?)
    end

    def voice_channels
      channels.select!(&:voice?)
    end

    def create_channel(name, reason = nil, type: :text, bitrate: nil, user_limit: nil, permissions: [], nsfw: false)
      raise ArgumentError, 'Invalid channel type specified' unless CHANNEL_TYPES.has_key?(type)

      permissions = permissions.map {|x| x.is_a(Overwrite) ? x.to_hash : x }
      response = MijDiscord::Core::API::Server.create_channel(@bot.auth, @id,
        name, CHANNEL_TYPES[type], bitrate, user_limit, permissions, nsfw, reason)
      @cache.put_channel(JSON.parse(response))
    end

    def create_role(name, reason = nil, color: 0, hoist: false, mentionable: false, permissions: 104_324_161)
      response = MijDiscord::Core::API::Server.create_role(@bot.auth, @id,
        name, color.to_i, hoist, mentionable, permissions.to_i, reason)
      @cache.put_role(JSON.parse(response))
    end

    def bans
      response = MijDiscord::Core::API::Server.bans(@bot.auth, @id)
      JSON.parse(response).map {|x| @bot.cache.put_user(x['user']) }
    end

    def ban(user, message_days = 0, reason = nil)
      MijDiscord::Core::API::Server.ban_user(@bot.auth, @id, user.to_id, message_days, reason)
      nil
    end

    def unban(user, reason = nil)
      MijDiscord::Core::API::Server.unban_user(@bot.auth, @id, user.to_id, reason)
      nil
    end

    def kick(user, reason = nil)
      MijDiscord::Core::API::Server.remove_member(@bot.auth, @id, user.to_id, reason)
      nil
    end

    def leave
      MijDiscord::Core::API::User.leave_server(@bot.auth, @id)
      nil
    end

    def delete
      MijDiscord::Core::API::Server.delete(@bot.auth, @id)
      nil
    end

    def set_owner(user, reason = nil)
      MijDiscord::Core::API::Server.transfer_ownership(@bot.auth, @id, user.to_id, reason)
    end

    alias_method :owner=, :set_owner

    def set_options(reason = nil, name: nil, region: nil, icon: nil, afk_channel: nil, afk_timeout: nil)
      response = MijDiscord::Core::API::Server.update(@bot.auth, @id,
        name, region, icon, afk_channel&.to_id, afk_timeout, reason)
      @bot.cache.put_server(JSON.parse(response), update: true)
    end

    def set_name(name, reason = nil)
      set_options(reason, name: name)
      nil
    end

    alias_method :name=, :set_name

    def available_regions
      return @voice_regions if @voice_regions

      response = MijDiscord::Core::API::Server.regions(@bot.auth, @id)
      @voice_regions = JSON.parse(response).map {|x| VoiceRegion.new(x) }
    end

    def region
      available_regions.find {|x| x.id == @region_id }
    end

    def set_region(region, reason = nil)
      region = region.to_s
      raise ArgumentError, 'Invalid region' unless available_regions.find {|x| x.id == region }

      set_options(reason, region: region)
      nil
    end

    alias_method :region=, :set_region

    def set_icon(icon, reason = nil)
      if icon.respond_to?(:read)
        buffer = Base64.strict_encode64(icon.read)
        icon = "data:image/jpg;base64,#{buffer}"
        set_options(reason, icon: icon)
      else
        set_options(reason, icon: icon.to_s)
      end
      nil
    end

    alias_method :icon=, :set_icon

    def set_afk_channel(channel, reason = nil)
      set_options(reason, afk_channel: channel.to_id)
      nil
    end

    alias_method :afk_channel=, :set_afk_channel

    def set_afk_timeout(timeout, reason = nil)
      set_options(reason, afk_timeout: timeout)
      nil
    end

    alias_method :afk_timeout=, :set_afk_timeout

    def icon_url(format = :png)
      return nil unless @icon_id
      MijDiscord::Core::API.icon_url(@id, @icon_id, format)
    end

    def embed_url(style = :shield)
      return nil unless @embed_enabled
      MijDiscord::Core::API.widget_url(@id, style)
    end

    def search_messages(limit: 25, offset: 0, sort_by: nil, sort_asc: false,
    nsfw: true, around: 2, content: nil, author: nil, channel: nil, mentions: nil,
    author_is: nil, author_not: nil, has: nil, has_not: nil, before: nil, after: nil)
      author = author ? [*author].map(&:to_id) : nil
      channel = channel ? [*channel].map(&:to_id) : nil
      mentions = mentions ? [*mentions].map(&:to_id) : nil

      has_not = has_not ? [*has_not].map {|x| "-#{x}" } : []
      author_not = author_not ? [*author_not].map {|x| "-#{x}" } : []

      has = has_not | (has ? [*has].map(&:to_s) : [])
      author_is = author_not | (author_is ? [*author_is].map(&:to_s) : [])

      before = before ? IDObject.synthesize(before) : nil
      after = after ? IDObject.synthesize(after) : nil

      options = {
        limit: limit,
        offset: offset,
        sort_by: sort_by,
        sort_order: sort_asc ? 'asc' : 'desc',
        context_size: around,
        include_nsfw: nsfw,
        author_id: author,
        author_type: author_is,
        channel_id: channel,
        mentions: mentions,
        max_id: before,
        min_id: after,
        content: content,
        has: has,
      }.delete_if {|_,v| v.nil? }

      response = MijDiscord::Core::API::Server.search_messages(@bot.auth, @id, options)
      SearchResults.new(JSON.parse(response), @bot)
    end

    def inspect
      MijDiscord.make_inspect(self,
      :id, :name, :owner, :member_count, :features, :embed_enabled, :verification_level,
      :content_filter_level, :default_notifications, :afk_timeout, :afk_channel)
    end
  end

  class SearchResults
    ResultData = Struct.new(:result, :context) do
      def inspect
        MijDiscord.make_inspect(self, :result, :context)
      end
    end

    attr_reader :total_count

    attr_reader :messages

    def initialize(data, bot)
      @total_count = data['total_results']

      @messages = data['messages'].map do |group|
        context = group.map {|x| Message.new(x, bot) }
        result = context.delete_at(context.length / 2)
        ResultData.new(result, context)
      end
    end

    def inspect
      MijDiscord.make_inspect(self, :total_count, :messages)
    end
  end
end