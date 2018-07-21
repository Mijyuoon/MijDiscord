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

    attr_reader :game

    filter_match(:user, on: :id_obj, cmp: :eql?)
    filter_match(:status, on: Symbol, cmp: :eql?)

    filter_match(:game, field: [:game, :name], on: [String, Regexp], cmp: :case)

    def initialize(bot, data)
      super(bot, bot.server(data['guild_id']))

      @user = @bot.user(data['user']['id'])
      @status = data['status'].to_sym

      if (game = data['game'])
        @game = MijDiscord::Data::Game.new(game)
      end
    end

    def member
      @server&.member(@user.id)
    end
  end
end