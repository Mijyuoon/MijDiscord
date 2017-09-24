# frozen_string_literal: true

module MijDiscord::Events
  class Server < Generic
    attr_reader :server

    filter_match(:server, field: [:server, :name], on: [String, Regexp], cmp: :case)
    filter_match(:server, on: :id_obj, cmp: :eql?)

    def initialize(bot, server)
      super(bot)

      @server = server
    end
  end

  class CreateServer < Server; end

  class UpdateServer < Server; end

  class DeleteServer < Server; end

  # class DeleteServer < Generic
  #   attr_reader :id
  #
  #   filter_match(:server, field: :id, on: :id_obj) {|x,k| x == k.to_id }
  #
  #   def initialize(bot, data)
  #     super(bot)
  #
  #     @id = data['id'].to_i
  #   end
  # end

  class UpdateEmoji < Server
    attr_reader :added

    attr_reader :removed

    delegate_method :emojis, to: :server

    def initialize(bot, server, old_emoji, new_emoji)
      super(bot, server)

      @added = new_emoji - old_emoji
      @removed = old_emoji - new_emoji
    end
  end

  class BanUser < Server
    attr_reader :user

    filter_match(:user, field: [:user, :name], on: [String, Regexp], cmp: :case)
    filter_match(:user, on: :id_obj, cmp: :eql?)

    def initialize(bot, server, user)
      super(bot, server)

      @user = user
    end
  end

  class UnbanUser < BanUser; end

  class UpdatePresence < Server
    attr_reader :user

    attr_reader :status

    filter_match(:user, on: :id_obj, cmp: :eql?)
    filter_match(:status, on: Symbol, cmp: :eql?)

    def initialize(bot, data)
      server = @bot.server(data['guild_id'])
      super(bot, server)

      @status = data['status'].to_sym
      @user = @bot.user(data['user']['id'])
    end
  end

  class UpdatePlaying < UpdatePresence
    attr_reader :game

    attr_reader :stream_type

    attr_reader :stream_url

    filter_match(:game, on: [String, Regexp], cmp: :case)
    filter_match(:stream_type, on: Integer, cmp: :eql?)

    def initialize(bot, data)
      super(bot, data)

      if (game = data['game'])
        @game = game['name']
        @stream_type = game['type']
        @stream_url = game['url']
      end
    end
  end
end