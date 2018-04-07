# frozen_string_literal: true

module MijDiscord::Core::API::Channel
  class << self
    # Get a channel's data
    # https://discordapp.com/developers/docs/resources/channel#get-channel
    def resolve(auth, channel_id)
      MijDiscord::Core::API.request(
        :channels_cid,
        channel_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}",
        Authorization: auth
      )
    end

    # Update a channel's data
    # https://discordapp.com/developers/docs/resources/channel#modify-channel
    def update(auth, channel_id, name, topic, nsfw, parent_id, position, bitrate, user_limit, overwrites, reason = nil)
      MijDiscord::Core::API.request(
        :channels_cid,
        channel_id,
        :patch,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}",
        {
          name: name, topic: topic, nsfw: nsfw,
          parent_id: parent_id, position: position,
          bitrate: bitrate, user_limit: user_limit,
          permission_overwrites: overwrites
        }.delete_if {|_, v| v.nil? }.to_json,
        Authorization: auth,
        content_type: :json,
        'X-Audit-Log-Reason': reason
      )
    end

    # Delete a channel
    # https://discordapp.com/developers/docs/resources/channel#deleteclose-channel
    def delete(auth, channel_id, reason = nil)
      MijDiscord::Core::API.request(
        :channels_cid,
        channel_id,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}",
        Authorization: auth,
        'X-Audit-Log-Reason': reason
      )
    end

    # Get a list of messages from a channel's history
    # https://discordapp.com/developers/docs/resources/channel#get-channel-messages
    def messages(auth, channel_id, amount, before = nil, after = nil, around = nil)
      MijDiscord::Core::API.request(
        :channels_cid_messages,
        channel_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/messages?limit=#{amount}#{"&before=#{before}" if before}#{"&after=#{after}" if after}#{"&around=#{around}" if around}",
        Authorization: auth
      )
    end

    # Get a single message from a channel's history by id
    # https://discordapp.com/developers/docs/resources/channel#get-channel-message
    def message(auth, channel_id, message_id)
      MijDiscord::Core::API.request(
        :channels_cid_messages_mid,
        channel_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/messages/#{message_id}",
        Authorization: auth
      )
    end

    # Send a message to a channel
    # https://discordapp.com/developers/docs/resources/channel#create-message
    def create_message(auth, channel_id, message, tts = false, embed = nil, mentions = [])
      MijDiscord::Core::API.request(
        :channels_cid_messages_mid,
        channel_id,
        :post,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/messages",
        { content: message, mentions: mentions, tts: tts, embed: embed }.to_json,
        Authorization: auth,
        content_type: :json
      )
    end

    # Send a file as a message to a channel
    # https://discordapp.com/developers/docs/resources/channel#upload-file
    def upload_file(auth, channel_id, file, caption = nil, tts = false)
      MijDiscord::Core::API.request(
        :channels_cid_messages_mid,
        channel_id,
        :post,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/messages",
        { file: file, content: caption, tts: tts },
        Authorization: auth
      )
    end

    # Edit a message
    # https://discordapp.com/developers/docs/resources/channel#edit-message
    def edit_message(auth, channel_id, message_id, message, mentions = [], embed = nil)
      MijDiscord::Core::API.request(
        :channels_cid_messages_mid,
        channel_id,
        :patch,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/messages/#{message_id}",
        { content: message, mentions: mentions, embed: embed }.to_json,
        Authorization: auth,
        content_type: :json
      )
    end

    # Delete a message
    # https://discordapp.com/developers/docs/resources/channel#delete-message
    def delete_message(auth, channel_id, message_id)
      MijDiscord::Core::API.request(
        :channels_cid_messages_mid,
        channel_id,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/messages/#{message_id}",
        Authorization: auth
      )
    end

    # Delete messages in bulk
    # https://discordapp.com/developers/docs/resources/channel#bulk-delete-messages
    def bulk_delete_messages(auth, channel_id, messages = [])
      MijDiscord::Core::API.request(
        :channels_cid_messages_bulk_delete,
        channel_id,
        :post,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/messages/bulk-delete",
        { messages: messages }.to_json,
        Authorization: auth,
        content_type: :json
      )
    end

    # Create a reaction on a message using this client
    # https://discordapp.com/developers/docs/resources/channel#create-reaction
    def create_reaction(auth, channel_id, message_id, emoji)
      emoji = URI.encode(emoji) unless emoji.ascii_only?
      MijDiscord::Core::API.request(
        :channels_cid_messages_mid_reactions_emoji_me,
        channel_id,
        :put,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}/@me",
        nil,
        Authorization: auth,
        content_type: :json,
        header_bypass_delay: 0.25
      )
    end

    # Delete this client's own reaction on a message
    # https://discordapp.com/developers/docs/resources/channel#delete-own-reaction
    def delete_own_reaction(auth, channel_id, message_id, emoji)
      emoji = URI.encode(emoji) unless emoji.ascii_only?
      MijDiscord::Core::API.request(
        :channels_cid_messages_mid_reactions_emoji_me,
        channel_id,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}/@me",
        Authorization: auth,
        header_bypass_delay: 0.25
      )
    end

    # Delete another client's reaction on a message
    # https://discordapp.com/developers/docs/resources/channel#delete-user-reaction
    def delete_user_reaction(auth, channel_id, message_id, emoji, user_id)
      emoji = URI.encode(emoji) unless emoji.ascii_only?
      MijDiscord::Core::API.request(
        :channels_cid_messages_mid_reactions_emoji_uid,
        channel_id,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}/#{user_id}",
        Authorization: auth,
        header_bypass_delay: 0.25
      )
    end

    # Get a list of clients who reacted with a specific reaction on a message
    # https://discordapp.com/developers/docs/resources/channel#get-reactions
    def get_reactions(auth, channel_id, message_id, emoji)
      emoji = URI.encode(emoji) unless emoji.ascii_only?
      MijDiscord::Core::API.request(
        :channels_cid_messages_mid_reactions_emoji,
        channel_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/messages/#{message_id}/reactions/#{emoji}",
        Authorization: auth
      )
    end

    # Deletes all reactions on a message from all clients
    # https://discordapp.com/developers/docs/resources/channel#delete-all-reactions
    def delete_all_reactions(auth, channel_id, message_id)
      MijDiscord::Core::API.request(
        :channels_cid_messages_mid_reactions,
        channel_id,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/messages/#{message_id}/reactions",
        Authorization: auth
      )
    end

    # Update a channels permission for a role or member
    # https://discordapp.com/developers/docs/resources/channel#edit-channel-permissions
    def update_permission(auth, channel_id, overwrite_id, allow, deny, type, reason = nil)
      MijDiscord::Core::API.request(
        :channels_cid_permissions_oid,
        channel_id,
        :put,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/permissions/#{overwrite_id}",
        { type: type, id: overwrite_id, allow: allow, deny: deny }.to_json,
        Authorization: auth,
        content_type: :json,
        'X-Audit-Log-Reason': reason
      )
    end

    # Get a channel's invite list
    # https://discordapp.com/developers/docs/resources/channel#get-channel-invites
    def invites(auth, channel_id)
      MijDiscord::Core::API.request(
        :channels_cid_invites,
        channel_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/invites",
        Authorization: auth
      )
    end

    # Create an instant invite from a server or a channel id
    # https://discordapp.com/developers/docs/resources/channel#create-channel-invite
    def create_invite(auth, channel_id, max_age = 0, max_uses = 0, temporary = false, unique = false, reason = nil)
      MijDiscord::Core::API.request(
        :channels_cid_invites,
        channel_id,
        :post,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/invites",
        { max_age: max_age, max_uses: max_uses, temporary: temporary, unique: unique }.to_json,
        Authorization: auth,
        content_type: :json,
        'X-Audit-Log-Reason': reason
      )
    end

    # Delete channel permission
    # https://discordapp.com/developers/docs/resources/channel#delete-channel-permission
    def delete_permission(auth, channel_id, overwrite_id, reason = nil)
      MijDiscord::Core::API.request(
        :channels_cid_permissions_oid,
        channel_id,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/permissions/#{overwrite_id}",
        Authorization: auth,
        'X-Audit-Log-Reason': reason
      )
    end

    # Start typing (needs to be resent every 5 seconds to keep up the typing)
    # https://discordapp.com/developers/docs/resources/channel#trigger-typing-indicator
    def start_typing(auth, channel_id)
      MijDiscord::Core::API.request(
        :channels_cid_typing,
        channel_id,
        :post,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/typing",
        nil,
        Authorization: auth
      )
    end

    # Get a list of pinned messages in a channel
    # https://discordapp.com/developers/docs/resources/channel#get-pinned-messages
    def pinned_messages(auth, channel_id)
      MijDiscord::Core::API.request(
        :channels_cid_pins,
        channel_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/pins",
        Authorization: auth
      )
    end

    # Pin a message
    # https://discordapp.com/developers/docs/resources/channel#add-pinned-channel-message
    def pin_message(auth, channel_id, message_id)
      MijDiscord::Core::API.request(
        :channels_cid_pins_mid,
        channel_id,
        :put,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/pins/#{message_id}",
        nil,
        Authorization: auth
      )
    end

    # Unpin a message
    # https://discordapp.com/developers/docs/resources/channel#delete-pinned-channel-message
    def unpin_message(auth, channel_id, message_id)
      MijDiscord::Core::API.request(
        :channels_cid_pins_mid,
        channel_id,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/pins/#{message_id}",
        Authorization: auth
      )
    end

    # Create an empty group channel.
    def create_empty_group(auth, bot_user_id)
      MijDiscord::Core::API.request(
        :users_uid_channels,
        nil,
        :post,
        "#{MijDiscord::Core::API::APIBASE_URL}/users/#{bot_user_id}/channels",
        {}.to_json,
        Authorization: auth,
        content_type: :json
      )
    end

    # Create a group channel.
    def create_group(auth, pm_channel_id, user_id)
      MijDiscord::Core::API.request(
        :channels_cid_recipients_uid,
        nil,
        :put,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{pm_channel_id}/recipients/#{user_id}",
        {}.to_json,
        Authorization: auth,
        content_type: :json
      )
    rescue RestClient::InternalServerError
      raise 'Attempted to add self as a new group channel recipient!'
    rescue RestClient::NoContent
      raise 'Attempted to create a group channel with the PM channel recipient!'
    rescue RestClient::Forbidden
      raise 'Attempted to add a user to group channel without permission!'
    end

    # Add a user to a group channel.
    def add_group_user(auth, group_channel_id, user_id)
      MijDiscord::Core::API.request(
        :channels_cid_recipients_uid,
        nil,
        :put,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{group_channel_id}/recipients/#{user_id}",
        {}.to_json,
        Authorization: auth,
        content_type: :json
      )
    end

    # Remove a user from a group channel.
    def remove_group_user(auth, group_channel_id, user_id)
      MijDiscord::Core::API.request(
        :channels_cid_recipients_uid,
        nil,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{group_channel_id}/recipients/#{user_id}",
        Authorization: auth,
        content_type: :json
      )
    end

    # Leave a group channel.
    def leave_group(auth, group_channel_id)
      MijDiscord::Core::API.request(
        :channels_cid,
        nil,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{group_channel_id}",
        Authorization: auth,
        content_type: :json
      )
    end

    # Create a webhook
    # https://discordapp.com/developers/docs/resources/webhook#create-webhook
    def create_webhook(auth, channel_id, name, avatar = nil, reason = nil)
      MijDiscord::Core::API.request(
        :channels_cid_webhooks,
        channel_id,
        :post,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/webhooks",
        { name: name, avatar: avatar }.to_json,
        Authorization: auth,
        content_type: :json,
        'X-Audit-Log-Reason': reason
      )
    end

    # Get channel webhooks
    # https://discordapp.com/developers/docs/resources/webhook#get-channel-webhooks
    def webhooks(auth, channel_id)
      MijDiscord::Core::API.request(
        :channels_cid_webhooks,
        channel_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/channels/#{channel_id}/webhooks",
        Authorization: auth
      )
    end
  end
end