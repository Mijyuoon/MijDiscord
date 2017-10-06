# frozen_string_literal: true

module MijDiscord::Data
  class Channel
    TYPES = {
      0 => :text,
      1 => :pm,
      2 => :voice,
      3 => :group,
      4 => :category,
    }.freeze

    include IDObject

    attr_reader :bot
  
    attr_reader :name

    attr_reader :server

    attr_reader :type

    attr_reader :position

    attr_reader :parent_id

    attr_reader :permission_overwrites
    alias_method :overwrites, :permission_overwrites

    attr_reader :cache

    def initialize(data, bot, server)
      @bot = bot
      @cache = MijDiscord::Cache::ChannelCache.new(self, @bot)

      data = data[-1] if data.is_a?(Array)

      @id = data['id'].to_i
      update_data(data)

      @server = server || @bot.server(data['guild_id']) unless private?
    end

    def self.create(data, bot, server)
      case TYPES[data['type']]
        when :text, :pm, :group
          TextChannel.new(data, bot, server)
        when :voice
          VoiceChannel.new(data, bot, server)
        when :category
          ChannelCategory.new(data, bot, server)
        else
          raise 'Broken channel object!'
      end
    end

    def update_data(data)
      @name = data.fetch('name', @name) unless pm?
      @type_id = data.fetch('type', @type_id || 0)
      @type = TYPES[@type_id]

      @position = data.fetch('position', @position)
      @parent_id = data.fetch('parent_id', @parent_id).to_i

      if (perms = data['permission_overwrites'])
        @permission_overwrites = {}

        perms.each do |elem|
          id = elem['id'].to_i
          @permission_overwrites[id] = Overwrite.from_hash(elem)
        end
      end
    end

    def mention
      "<##{@id}>"
    end

    alias_method :to_s, :mention

    def text?
      @type == :text
    end

    def pm?
      @type == :pm
    end

    alias_method :dm?, :pm?

    def voice?
      @type == :voice
    end

    def group?
      @type == :group
    end

    def category?
      @type == :category
    end

    def private?
      pm? || group?
    end

    def default_channel?
      @server.default_channel == self
    end

    alias_method :default?, :default_channel?

    def parent
      @parent_id ? @server.cache.get_channel(@parent_id) : nil
    end

    alias_method :category, :parent

    def member_overwrites
      @permission_overwrites.values.select {|v| v.type == :member }
    end

    def role_overwrites
      @permission_overwrites.values.select {|v| v.type == :role }
    end

    def set_name(name, reason = nil)
      set_options(reason, name: name)
      nil
    end

    alias_method :name=, :set_name

    def set_position(position, reason = nil)
      set_options(reason, position: position)
      nil
    end

    alias_method :position=, :set_position

    def set_parent(parent, reason = nil)
      channel = @server.cache.get_channel(parent)
      raise ArgumentError, 'Specified channel is not a category' unless channel&.category?

      set_options(reason, parent: channel)
      nil
    end

    alias_method :parent=, :set_parent
    alias_method :set_category, :set_parent
    alias_method :category=, :set_parent

    def set_options(reason = nil, name: nil, topic: nil, nsfw: nil,
    parent: nil, position: nil, bitrate: nil, user_limit: nil, overwrites: nil)
      response = MijDiscord::Core::API::Channel.update(@bot.token, @id,
        name, topic, nsfw,parent&.to_id, position, bitrate, user_limit, overwrites, reason)
      @server.cache.put_channel(JSON.parse(response), update: true)
    end

    def set_overwrites(overwrites, reason = nil)
      set_options(reason, overwrites: overwrites)
      nil
    end

    alias_method :overwrites=, :set_overwrites
    alias_method :set_permission_overwrites, :set_overwrites
    alias_method :permission_overwrites=, :set_overwrites

    def define_overwrite(object, reason = nil, allow: 0, deny: 0)
      unless object.is_a?(Overwrite)
        allow_bits = allow.respond_to?(:bits) ? allow.bits : allow
        deny_bits = deny.respond_to?(:bits) ? deny.bits : deny

        object = Overwrite.new(object, allow: allow_bits, deny: deny_bits)
      end

      MijDiscord::Core::API::Channel.update_permission(@bot.token, @id,
        object.id, object.allow.bits, object.deny.bits, object.type, reason)
      nil
    end

    alias_method :add_overwrite, :define_overwrite
    alias_method :define_permission_overwrite, :define_overwrite
    alias_method :add_permission_overwrite, :define_overwrite

    def delete_overwrite(object, reason = nil)
      raise ArgumentError, 'Invalid overwrite target' unless object.respond_to?(:to_id)
      MijDiscord::Core::API::Channel.delete_permission(@bot.token, @id,
        object.to_id, reason)
      nil
    end

    alias_method :delete_permission_overwrite, :delete_overwrite

    def sync_overwrites(reason = nil)
      raise 'Cannot sync overwrites on a channel with no category set' unless @parent_id
      set_overwrites(parent.overwrites, reason)
      nil
    end

    alias_method :sync_permission_overwrites, :sync_overwrites

    def delete(reason = nil)
      MijDiscord::Core::API::Channel.delete(@bot.token, @id, reason)
      @server.cache.remove_channel(@id)
    end

    def inspect
      %(<Channel id=#{@id} server=#{@server.id} name="#{@name}" type=#{@type}>)
    end
  end

  class TextChannel < Channel
    attr_reader :topic

    attr_reader :owner_id

    attr_reader :nsfw
    alias_method :nsfw?, :nsfw

    attr_reader :recipients

    attr_reader :last_message_id

    def initialize(data, bot, server)
      super(data, bot, server)

      @last_message_id = data['last_message_id']

      if private?
        @recipients = []
        if data['recipients']
          data['recipients'].each do |rd|
            user = @bot.cache.put_user(rd)
            @recipients << Recipient.new(user, self, @bot)
          end
        end

        if pm?
          @name = @recipients.first.username
        else
          @owner_id = data['owner_id'].to_i
        end
      end
    end

    def update_data(data)
      super(data)

      @topic = data.fetch('topic', @topic)
      @nsfw = data.fetch('nsfw', @nsfw)
    end

    def update_recipient(add: nil, remove: nil)
      return unless group?

      unless add.nil?
        user = @bot.cache.put_user(add)
        recipient = Recipient.new(user, self, @bot)
        @recipients << recipient
        return recipient
      end

      unless remove.nil?
        id = remove['id'].to_i
        recipient = @recipients.find {|x| x.id == id }
        return @recipients.delete(recipient)
      end
    end

    def recipient
      @recipients&.first
    end

    def owner
      @owner_id ? @bot.cache.get_user(@owner_id) : nil
    end

    def last_message
      @last_message_id ? @cache.get_message(@last_message_id) : nil
    end

    def set_topic(topic, reason = nil)
      return unless text?

      set_options(reason, topic: topic)
      nil
    end

    alias_method :topic=, :set_topic

    def set_nsfw(nsfw, reason = nil)
      return unless text?

      set_options(reason, nsfw: nsfw)
      nil
    end

    alias_method :nsfw=, :set_nsfw

    def send_message(text: '', embed: nil, tts: false)
      raise MijDiscord::Core::Errors::MessageTooLong if text.length > 2000

      response = MijDiscord::Core::API::Channel.create_message(@bot.token, @id,
        text, tts, embed&.to_h)
      @cache.put_message(JSON.parse(response))
    end

    def send_file(file, caption: '', tts: false)
      raise MijDiscord::Core::Errors::MessageTooLong if caption.length > 2000

      response = MijDiscord::Core::API::Channel.upload_file(@bot.token, @id, file, caption, tts)
      @cache.put_message(JSON.parse(response))
    end

    def delete_message(message)
      MijDiscord::Core::API::Channel.delete_message(@bot.token, @id, message.to_id)
      @cache.remove_message(message)
    end

    def message(id)
      @cache.get_message(id)
    end

    def message_history(amount, before: nil, after: nil, around: nil)
      response = MijDiscord::Core::API::Channel.messages(@bot.token, @id,
        amount, before&.to_id, after&.to_id, around&.to_id)
      JSON.parse(response).map {|m| Message.new(m, @bot) }
    end

    alias_method :history, :message_history

    def pinned_messages
      response = MijDiscord::Core::API::Channel.pinned_messages(@bot.token, @id)
      JSON.parse(response).map {|m| Message.new(m, @bot) }
    end

    alias_method :pinned, :pinned_messages

    def delete_messages(messages)
      two_weeks = Time.now - (14 * 86_400)
      min_snowflake = IDObject.synthesize(two_weeks)
      ids = messages.map(&:to_id).delete_if {|m| m < min_snowflake }

      MijDiscord::Core::API::Channel.bulk_delete_messages(@bot.token, @id, ids)
      ids.each {|m| @cache.remove_message(m) }
      nil
    end

    def invites
      response = MijDiscord::Core::API::Channel.invites(@bot.token, @id)
      JSON.parse(response).map {|x| Invite.new(x, @bot) }
    end

    def make_invite(reason = nil, max_age: 0, max_uses: 0, temporary: false, unique: false)
      response = MijDiscord::Core::API::Channel.create_invite(@bot.token, @id,
        max_age, max_uses, temporary, unique, reason)
      Invite.new(JSON.parse(response), @bot)
    end

    alias_method :invite, :make_invite

    def start_typing
      MijDiscord::Core::API::Channel.start_typing(@bot.token, @id)
      nil
    end

    def create_group(users)
      raise 'Attempted to create group channel on a non-pm channel' unless pm?

      ids = users.map(&:to_id)
      response = MijDiscord::Core::API::Channel.create_group(@bot.token, @id, ids.shift)
      channel = @bot.cache.put_channel(JSON.parse(response))
      channel.add_group_users(ids)

      channel
    end

    def add_group_users(users)
      raise 'Attempted to add a user to a non-group channel' unless group?

      users.each do |u|
        MijDiscord::Core::API::Channel.add_group_user(@bot.token, @id, u.to_id)
      end
      nil
    end

    def remove_group_users(users)
      raise 'Attempted to remove a user to a non-group channel' unless group?

      users.each do |u|
        MijDiscord::Core::API::Channel.remove_group_user(@bot.token, @id, u.to_id)
      end
      nil
    end

    def leave_group
      raise 'Attempoted to leave a non-group channel' unless group?

      MijDiscord::Core::API::Channel.leave_group(@bot.token, @id)
      nil
    end
  end

  class VoiceChannel < Channel
    attr_reader :bitrate

    attr_reader :user_limit
    alias_method :limit, :user_limit

    def initialize(data, bot, server)
      super(data, bot, server)
    end

    def update_data(data)
      super(data)

      @bitrate = data.fetch('bitrate', @bitrate)
      @user_limit = data.fetch('user_limit', @user_limit)
    end

    def set_bitrate(rate, reason = nil)
      set_options(reason, bitrate: rate)
      nil
    end

    alias_method :bitrate=, :set_bitrate

    def set_user_limit(limit, reason = nil)
      set_options(reason, user_limit: limit)
      nil
    end

    alias_method :user_limit=, :set_user_limit
    alias_method :set_limit, :set_user_limit
    alias_method :limit=, :set_user_limit
  end

  class ChannelCategory < Channel
    def initialize(data, bot, server)
      super(data, bot, server)
    end

    def update_data(data)
      super(data)
    end

    def channels
      @server.channels.select! {|x| x.parent_id == @id }
    end

    alias_method :children, :channels
  end
end