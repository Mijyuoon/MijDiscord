# frozen_string_literal: true

module MijDiscord::Data
  class Permissions
    FLAGS = {
      # (1 << Bit) => Permission # Value
      (1 << 0) => :create_instant_invite,   # 1
      (1 << 1) => :kick_members,            # 2
      (1 << 2) => :ban_members,             # 4
      (1 << 3) => :administrator,           # 8
      (1 << 4) => :manage_channels,         # 16
      (1 << 5) => :manage_server,           # 32
      (1 << 6) => :add_reactions,           # 64
      (1 << 7) => :view_audit_log,          # 128
      # 1 << 8                              # 256
      # 1 << 9                              # 512
      (1 << 10) => :read_messages,          # 1024
      (1 << 11) => :send_messages,          # 2048
      (1 << 12) => :send_tts_messages,      # 4096
      (1 << 13) => :manage_messages,        # 8192
      (1 << 14) => :embed_links,            # 16384
      (1 << 15) => :attach_files,           # 32768
      (1 << 16) => :read_message_history,   # 65536
      (1 << 17) => :mention_everyone,       # 131072
      (1 << 18) => :use_external_emoji,     # 262144
      # 1 << 19                             # 524288
      (1 << 20) => :connect,                # 1048576
      (1 << 21) => :speak,                  # 2097152
      (1 << 22) => :mute_members,           # 4194304
      (1 << 23) => :deafen_members,         # 8388608
      (1 << 24) => :move_members,           # 16777216
      (1 << 25) => :use_voice_activity,     # 33554432
      (1 << 26) => :change_nickname,        # 67108864
      (1 << 27) => :manage_nicknames,       # 134217728
      (1 << 28) => :manage_roles,           # 268435456
      (1 << 29) => :manage_webhooks,        # 536870912
      (1 << 30) => :manage_emojis,          # 1073741824
    }.freeze

    def self.bits(list)
      FLAGS.map {|bit, name| list.include?(name) ? bit : 0 }.reduce(&:|)
    end

    FLAGS.each do |bit, name|
      attr_reader name
      alias_method :"#{name}?", name

      define_method(:"can_#{name}=") do |flag|
        set_bits(flag ? (@bits | bit) : (@bits & ~bit))
      end
    end

    alias_method :can_administrate=, :can_administrator=
    alias_method :administrate, :administrator
    alias_method :administrate?, :administrator?

    attr_reader :bits
    alias_method :to_i, :bits

    def initialize(bits = 0)
      set_bits(bits)
    end

    def set_bits(bits)
      @bits = bits.is_a?(Array) ? Permissions.bits(bits) : bits

      FLAGS.each do |bit, name|
        flag = !(@bits & bit).zero?
        instance_variable_set "@#{name}", flag
      end
    end

    alias_method :bits=, :set_bits
  end

  class Overwrite
    include IDObject

    attr_accessor :type

    attr_accessor :allow

    attr_accessor :deny

    def initialize(object, type: nil, allow: 0, deny: 0)
      case type
        when nil, :member, :role
          # Do nothing
        else
          raise ArgumentError, 'Overwrite type must be :member or :role'
      end

      @id = object.to_id

      @type = case object
        when User, Member, Recipient, Profile
          :member
        when Role
          :role
        else
          type
      end

      @allow = allow.is_a?(Permissions) ? allow : Permissions.new(allow)
      @deny = deny.is_a?(Permissions) ? deny : Permissions.new(deny)
    end

    def self.from_hash(data)
      Overwrite.new(
        data['id'].to_i,
        type: data['type'].to_sym,
        allow: Permissions.new(data['allow']),
        deny: Permissions.new(data['deny'])
      )
    end

    def to_hash
      { id: @id, type: @type, allow: @allow.bits, deny: @deny.bits }
    end
  end
end