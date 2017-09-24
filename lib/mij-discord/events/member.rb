# frozen_string_literal: true

module MijDiscord::Events
  class Role < Server
    attr_reader :role

    filter_match(:role, field: [:role, :name], on: [String, Regexp], cmp: :case)
    filter_match(:role, on: :id_obj, cmp: :eql?)

    def initialize(bot, server, role)
      super(bot, server)

      @role = role
    end
  end

  class CreateRole < Role; end

  class UpdateRole < Role; end

  class DeleteRole < Role; end

  # class DeleteRole < Server
  #   attr_reader :id
  #
  #   filter_match(:role, field: :id, on: :id_obj) {|x,k| x == k.to_id }
  #
  #   def initialize(bot, server, data)
  #     super(bot, server)
  #
  #     @id = data['id'].to_i
  #   end
  # end

  class Member < Server
    attr_reader :user
    alias_method :member, :user

    filter_match(:user, field: [:user, :name], on: [String, Regexp], cmp: :case)
    filter_match(:user, on: :id_obj, cmp: :eql?)

    def initialize(bot, user, server = nil)
      super(bot, server || user.server)

      @user = user
    end
  end

  class CreateMember < Member; end

  class UpdateMember < Member; end

  class DeleteMember < Member; end

  class UpdateVoiceState < Member
    attr_reader :state

    delegate_method :mute?, :deaf?, :self_mute?, :self_deaf?, :voice_channel, to: :state

    def initialize(bot, user, state)
      super(bot, user)

      @state = state
    end
  end
end