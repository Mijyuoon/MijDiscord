# frozen_string_literal: true

module MijDiscord::Data
  class VoiceState
    attr_reader :user

    attr_reader :mute
    alias_method :mute?, :mute

    attr_reader :deaf
    alias_method :deaf?, :deaf

    attr_reader :self_mute
    alias_method :self_mute?, :self_mute

    attr_reader :self_deaf
    alias_method :self_deaf?, :self_deaf

    attr_reader :voice_channel
    alias_method :channel, :voice_channel

    def initialize(user)
      @user = user
    end

    def update_data(channel, data)
      @voice_channel = channel

      @mute = data.fetch('mute', @mute)
      @deaf = data.fetch('deaf', @deaf)
      @self_mute = data.fetch('self_mute', @self_mute)
      @self_deaf = data.fetch('self_deaf', @self_deaf)
    end
  end

  class VoiceRegion
    attr_reader :id
    alias_method :to_s, :id

    attr_reader :name

    attr_reader :sample_hostname

    attr_reader :sample_port

    attr_reader :vip

    attr_reader :optimal

    attr_reader :deprecated

    attr_reader :custom

    def initialize(data)
      @id = data['id']

      @name = data['name']

      @sample_hostname = data['sample_hostname']
      @sample_port = data['sample_port']

      @vip = data['vip']
      @optimal = data['optimal']
      @deprecated = data['deprecated']
      @custom = data['custom']
    end
  end
end