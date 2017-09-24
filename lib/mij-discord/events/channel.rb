# frozen_string_literal: true

module MijDiscord::Events
  class Channel < Generic
    attr_reader :channel

    delegate_method :name, :server, :type, :owner, :nsfw?, :text?, :pm?, :voice?, :group?, to: :channel

    filter_match(:type, on: Symbol, cmp: :eql?)

    filter_match(:channel, field: [:channel, :name], on: [String, Regexp], cmp: :case)
    filter_match(:channel, on: :id_obj, cmp: :eql?)

    filter_match(:server, field: [:server, :name], on: [String, Regexp], cmp: :case)
    filter_match(:server, on: :id_obj, cmp: :eql?)

    filter_match(:owner, field: [:owner, :name], on: [String, Regexp], cmp: :case)
    filter_match(:owner, on: :id_obj, cmp: :eql?)

    def initialize(bot, channel)
      super(bot)

      @channel = channel
    end
  end

  class CreateChannel < Channel; end

  class UpdateChannel < Channel; end

  class DeleteChannel < Channel; end

  class Recipient < Channel
    attr_reader :recipient
    alias_method :user, :recipient

    filter_match(:user, field: [:user, :name], on: [String, Regexp], cmp: :case)
    filter_match(:user, on: :id_obj, cmp: :eql?)

    def initialize(bot, channel, recipient)
      super(bot, channel)

      @recipient = recipient
    end
  end

  class AddRecipient < Recipient; end

  class RemoveRecipient < Recipient; end
end