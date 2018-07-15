# frozen_string_literal: true

module MijDiscord::Data
  class Game
    PLAYING_TYPE = [
      :playing,
      :streaming,
      :listening,
      :watching,
    ].freeze

    attr_reader :name

    attr_reader :url

    attr_reader :details

    attr_reader :state

    attr_reader :start_time

    attr_reader :end_time

    attr_reader :application

    attr_reader :large_image

    attr_reader :large_text

    attr_reader :small_image

    attr_reader :small_text

    def type
      PLAYING_TYPE[@type]
    end

    def initialize(data)
      @type = data['type']
      @name = data['name']
      @url = data['url']
      @details = data['details']
      @state = data['state']
      @application = data['application_id']

      if (start_time = data.dig('timestamps', 'start'))
        @start_time = Time.at(start_time).utc
      end
      if (end_time = data.dig('timestamps', 'end'))
        @end_time = Time.at(end_time).utc
      end

      if (assets = data['assets'])
        @large_image = assets['large_image']
        @large_text = assets['large_text']
        @small_image = assets['small_image']
        @small_text = assets['small_text']
      end
    end

    def to_hash
      self.class.construct({
        start_time: @start_time,
        end_time: @end_time,

        large_image: @large_image,
        large_text: @large_text,
        small_image: @small_image,
        small_text: @small_text,

        type: @type,
        name: @name,
        url: @url,
        details: @details,
        state: @state,
        application: @application,
      })
    end

    def inspect
      MijDiscord.make_inspect(self,
        :type, :name, :url, :details, :state, :start_time, :end_time,
        :application, :large_image, :large_text, :small_image, :small_text)
    end

    def self.construct(data)
      data = {name: data} if data.is_a?(String)

      times = {
        start: data.try_keys(:start_time, 'start_time')&.to_i,
        end: data.try_keys(:end_time, 'end_time')&.to_i,
      }.delete_if {|_,v| v.nil? }

      assets = {
        large_image: data.try_keys(:large_image, 'large_image')&.to_s,
        large_text: data.try_keys(:large_text, 'large_text')&.to_s,
        small_image: data.try_keys(:small_image, 'small_image')&.to_s,
        small_text: data.try_keys(:small_text, 'small_text')&.to_s,
      }.delete_if {|_,v| v.nil? }

      game = {
        type: PLAYING_TYPE.index(data.try_keys(:type, 'type')).to_i,
        name: data.try_keys(:name, 'name')&.to_s,
        url: data.try_keys(:url, 'url')&.to_s,
        details: data.try_keys(:details, 'details')&.to_s,
        state: data.try_keys(:state, 'state')&.to_s,
        application_id: data.try_keys(:application, 'application')&.to_s,

        timestamps: times.empty? ? nil : times,
        assets: assets.empty? ? nil : assets,
      }.delete_if {|_,v| v.nil? }

      game
    end
  end

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

    attr_reader :extra

    def initialize(data, bot)
      @bot = bot

      # Kludge for User::resolve2 API call
      data = data['user'] if data['user'].is_a?(Hash)

      @id = data['id'].to_i
      @bot_account = !!data['bot']
      update_data(data)

      @status, @game = :offline, nil

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
        @game = Game.new(game)
      else
        @game = nil
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

    alias_method :avatar, :avatar_url

    def inspect
      MijDiscord.make_inspect(self,
        :id, :username, :discriminator, :avatar_id, :bot_account)
    end

    class << self
      def process_avatar(data, format = :png, empty = false)
        if data.is_a?(String)
          "data:image/#{format};base64,#{data}"
        elsif data.respond_to?(:read)
          data.binmode if data.respond_to?(:binmode)
          data = Base64.strict_encode64(data.read)
          "data:image/#{format};base64,#{data}"
        elsif empty && %i[none empty].include?(data)
          nil
        else
          raise ArgumentError, 'Invalid avatar data provided'
        end
      end
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
      response = MijDiscord::Core::API::User.update_profile(@bot.auth, name, nil)
      update_data(JSON.parse(response))
      nil
    end

    alias_method :username=, :set_username
    alias_method :set_name, :set_username
    alias_method :name=, :set_username

    def set_avatar(data, format = :png)
      data = User.process_avatar(data, format, false)
      response = MijDiscord::Core::API::User.update_profile(@bot.auth, nil, data)
      update_data(JSON.parse(response))
      nil
    end

    alias_method :avatar=, :set_avatar
  end
end