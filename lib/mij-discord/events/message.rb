# frozen_string_literal: true

module MijDiscord::Events
  class Message < Generic
    attr_reader :message

    delegate_method :author, :user, :channel, :content, :text, :timestamp, to: :message

    delegate_method :server, to: :channel

    filter_match(:message, on: :id_obj, cmp: :eql?)

    filter_match(:user, field: [:user, :name], on: [String, Regexp], cmp: :case)
    filter_match(:user, on: :id_obj, cmp: :eql?)

    filter_match(:channel, field: [:channel, :name], on: [String, Regexp], cmp: :case)
    filter_match(:channel, on: :id_obj, cmp: :eql?)

    filter_match(:server, field: [:server, :name], on: [String, Regexp], cmp: :case)
    filter_match(:server, on: :id_obj, cmp: :eql?)

    filter_match(:before, field: :timestamp, on: Time) {|x,k| x < k }
    filter_match(:after, field: :timestamp, on: Time) {|x,k| x > k }

    filter_match(:include, field: :content, on: Regexp, cmp: :case)
    filter_match(:include, field: :content, on: String) {|x,k| x.include?(k) }

    filter_match(:start_with, field: :content, on: String) {|x,k| x.start_with?(k) }
    filter_match(:end_with, field: :content, on: String) {|x,k| x.end_with?(k) }

    def initialize(bot, message)
      super(bot)

      @message = message
    end
  end

  class CreateMessage < Message; end

  class ChannelMessage < Message; end

  class PrivateMessage < Message; end

  class EditMessage < Message; end

  class DeleteMessage < Generic
    attr_reader :id

    attr_reader :channel

    delegate_method :server, to: :channel

    filter_match(:message, field: :id, on: :id_obj) {|x,k| x == k.to_id }

    filter_match(:channel, field: [:channel, :name], on: [String, Regexp], cmp: :case)
    filter_match(:channel, on: :id_obj, cmp: :eql?)

    filter_match(:server, field: [:server, :name], on: [String, Regexp], cmp: :case)
    filter_match(:server, on: :id_obj, cmp: :eql?)

    def initialize(bot, data)
      super(bot)

      @id = data['id'].to_i
      @channel = @bot.channel(data['channel_id'])
    end
  end

  class StartTyping < Generic
    attr_reader :channel

    attr_reader :user
    alias_method :author, :user

    attr_reader :timestamp

    delegate_method :server, to: :channel

    filter_match(:user, field: [:user, :name], on: [String, Regexp], cmp: :case)
    filter_match(:user, on: :id_obj, cmp: :eql?)

    filter_match(:channel, field: [:channel, :name], on: [String, Regexp], cmp: :case)
    filter_match(:channel, on: :id_obj, cmp: :eql?)

    filter_match(:server, field: [:server, :name], on: [String, Regexp], cmp: :case)
    filter_match(:server, on: :id_obj, cmp: :eql?)

    filter_match(:before, field: :timestamp, on: Time) {|x,k| x < k }
    filter_match(:after, field: :timestamp, on: Time) {|x,k| x > k }

    def initialize(bot, data)
      super(bot)

      @timestamp = Time.at(data['timestamp'].to_i).utc
      @channel = @bot.channel(data['channel_id'])

      @user = if @channel.pm?
        @channel.recipient
      elsif @channel.group?
        @bot.user(data['user_id'])
      else
        @bot.member(@channel.server, data['user_id'])
      end
    end
  end

  class Reaction < Generic
    attr_reader :emoji

    attr_reader :user

    attr_reader :channel

    attr_reader :message_id

    delegate_method :server, to: :channel

    filter_match(:message, field: :message_id, on: :id_obj) {|x,k| x == k.to_id }

    filter_match(:emoji, field: [:emoji, :name], on: [String, Regexp], cmp: :case)
    filter_match(:emoji, field: [:emoji, :id], on: :id_obj) {|x,k| x == k.to_id }

    def initialize(bot, data)
      super(bot)

      @message_id = data['message_id'].to_i
      @channel = @bot.channel(data['channel_id'])

      user_id, server = data['user_id'], @channel.server
      @user = server ? server.member(user_id) : @bot.user(user_id) if user_id

      if (emoji = data['emoji'])
        @emoji = server&.emoji(emoji['id'])
        @emoji ||= MijDiscord::Data::Emoji.new(emoji, @bot, nil)
      end
    end

    def message
      @channel.message(@message_id)
    end
  end

  class AddReaction < Reaction; end

  class RemoveReaction < Reaction; end

  class ToggleReaction < Reaction; end

  class ClearReactions < Reaction; end
end