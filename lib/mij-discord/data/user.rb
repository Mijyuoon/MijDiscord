# frozen_string_literal: true

module MijDiscord::Data
  class User
    include IDObject

    attr_reader :bot

    attr_reader :username
    alias_method :name, :username

    attr_reader :discriminator
    alias_method :tag, :discriminator

    attr_reader :bot_account
    alias_method :bot_account?, :bot_account

    attr_reader :avatar_id

    attr_reader :status

    attr_reader :game

    attr_reader :stream_url

    attr_reader :stream_type

    def initialize(data, bot)
      @bot = bot

      @id = data['id'].to_i
      @bot_account = !!data['bot']
      update_data(data)

      @status = :offline

      @roles = {}
    end

    def update_data(data)
      @username = data.fetch('username', @username)
      @discriminator = data.fetch('discriminator', @discriminator)
      @avatar_id = data.fetch('avatar', @avatar_id)
    end

    def update_presence(presence)
      @status = presence['status'].to_sym

      if (game = presence['game'])
        @game = game['name']
        @stream_url = game['url']
        @stream_type = game['type']
      else
        @game = @stream_url = @stream_type = nil
      end
    end

    def mention
      "<@#{@id}>"
    end

    alias_method :to_s, :mention

    def distinct
      "#{@username}##{@discriminator}"
    end

    def pm(text: nil, embed: nil)
      if text || embed
        pm.send_message(text: text || '', embed: embed)
      else
        @bot.pm_channel(@id)
      end
    end

    alias_method :dm, :pm

    def send_file(file, caption: nil)
      pm.send_file(file, caption: caption)
    end

    def on(server)
      id = server.to_id
      @bot.server(id).member(@id)
    end

    def webhook?
      @discriminator == '0000'
    end

    def current_bot?
      @bot.profile == self
    end

    def online?
      @status == :online?
    end

    def idle?
      @status == :idle
    end

    alias_method :away?, :idle?

    def dnd?
      @status == :dnd
    end

    alias_method :busy?, :dnd?

    def invisible?
      @status == :invisible
    end

    alias_method :hidden?, :invisible?

    def offline?
      @status == :offline
    end

    def member?
      false
    end

    def avatar_url(format = nil)
      return MijDiscord::Core::API::User.default_avatar(@discriminator) unless @avatar_id
      MijDiscord::Core::API::User.avatar_url(@id, @avatar_id, format)
    end

    def inspect
      %(<User id=#{@id} name="#{@username}" tag=#{@discriminator}>)
    end
  end

  class Profile < User
    attr_reader :mfa_enabled
    alias_method :mfa_enabled?, :mfa_enabled

    def update_data(data)
      super(data)

      @mfa_enabled = !!data['mfa_enabled']
    end

    def set_username(name)
      response = MijDiscord::Core::API::User.update_profile(@bot.token, name, nil)
      update_data(JSON.parse(response))
      nil
    end

    alias_method :username=, :set_username
    alias_method :set_name, :set_username
    alias_method :name=, :set_username

    def set_avatar(data, format = :png)
      if data.is_a?(String)
        data = "data:image/#{format};base64,#{data}"
      elsif data.respond_to?(:read)
        data.binmode if data.respond_to?(:binmode)
        data = Base64.strict_encode64(data.read)
        data = "data:image/#{format};base64,#{data}"
      else
        raise ArgumentError, 'Invalid avatar data provided'
      end

      response = MijDiscord::Core::API::User.update_profile(@bot.token, @username, data)
      update_data(JSON.parse(response))
      nil
    end

    alias_method :avatar=, :set_avatar
  end
end