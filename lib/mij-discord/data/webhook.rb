# frozen_string_literal: true

module MijDiscord::Data
  class Webhook
    include IDObject

    attr_reader :bot

    attr_reader :name

    attr_reader :channel

    attr_reader :token

    attr_reader :avatar_id

    attr_reader :owner

    def initialize(data, bot)
      @bot = bot

      @id = data['id'].to_id
      @token = data['token']
      update_data(data)

      if (user = data['user'])
        unless (@owner = server.member(user['id']))
          @owner = @bot.cache.put_user(user)
        end
      end
    end

    def update_data(data)
      @name = data['name']
      @channel = @bot.channel(data['channel_id'])
      @avatar_id = data['avatar']
    end

    def via_token?
      @owner.nil?
    end

    def server
      @channel.server
    end

    def avatar_url(format = nil)
      return MijDiscord::Core::API::User.default_avatar(0) unless @avatar_id
      MijDiscord::Core::API::User.avatar_url(@id, @avatar_id, format)
    end

    alias_method :avatar, :avatar_url

    def set_options(reason = nil, name: nil, channel: nil, avatar: nil, format: :png)
      data = {name: name, channel_id: channel&.to_id}
      data[:avatar] = User.process_avatar(avatar, format, true) unless avatar.nil?
      update_webhook(reason, **data.delete_if {|_,v| v.nil? })
    end

    def set_name(name, reason = nil)
      update_webhook(reason, name: name)
    end

    alias_method :name=, :set_name

    def set_channel(channel, reason = nil)
      update_webhook(reason, channel_id: channel.to_id)
    end

    alias_method :channel=, :set_channel

    def set_avatar(data, format = :png, reason = nil)
      data = User.process_avatar(data, format, true)
      update_webhook(reason, avatar: data)
    end

    alias_method :avatar=, :set_avatar

    def delete(reason = nil)
      if via_token?
        MijDiscord::Core::API::Webhook.token_delete_webhook(@token, @id, reason)
      else
        MijDiscord::Core::API::Webhook.delete_webhook(@bot.auth, @id, reason)
      end

      nil
    end

    def execute(text: '', name: nil, avatar: nil, tts: false, embeds: [], file: nil, wait: true)
      raise 'Not yet implemented' unless file.nil? # TODO: Implement

      params = {
        content: text,
        username: name,
        avatar_url: avatar,
        tts: tts,
        embeds: embeds.map(&:to_hash),
      }.delete_if {|_,v| v.nil? }

      response = MijDiscord::Core::API::Webhook.execute_json(@token, @id, params, wait)
      wait ? Message.new(JSON.parse(response), @bot) : nil
    end

    def inspect
      MijDiscord.make_inspect(self, :id, :name, :channel, :owner)
    end

    private

    def update_webhook(reason, **data)
      response = if via_token?
        MijDiscord::Core::API::Webhook.token_update_webhook(@token, @id, data, reason)
      else
        MijDiscord::Core::API::Webhook.update_webhook(@bot.auth, @id, data, reason)
      end

      update_data(JSON.parse(response))
      nil
    end
  end
end