# frozen_string_literal: true

module MijDiscord::Core::API::Server
  class << self
    # Create a server
    # https://discordapp.com/developers/docs/resources/guild#create-guild
    def create(auth, name, region = :'eu-central')
      MijDiscord::Core::API.request(
        :guilds,
        nil,
        :post,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds",
        { name: name, region: region.to_s }.to_json,
        Authorization: auth,
        content_type: :json
      )
    end

    # Get a server's data
    # https://discordapp.com/developers/docs/resources/guild#get-guild
    def resolve(auth, server_id)
      MijDiscord::Core::API.request(
        :guilds_sid,
        server_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}",
        Authorization: auth
      )
    end

    # Update a server
    # https://discordapp.com/developers/docs/resources/guild#modify-guild
    def update(auth, server_id, name, region, icon, afk_channel_id, afk_timeout, reason = nil)
      MijDiscord::Core::API.request(
        :guilds_sid,
        server_id,
        :patch,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}",
        {
          name: name, region: region, icon: icon,
          afk_channel_id: afk_channel_id, afk_timeout: afk_timeout
        }.delete_if {|_, v| v.nil? }.to_json,
        Authorization: auth,
        content_type: :json,
        'X-Audit-Log-Reason': reason
      )
    end

    # Transfer server ownership
    def transfer_ownership(auth, server_id, user_id, reason = nil)
      MijDiscord::Core::API.request(
        :guilds_sid,
        server_id,
        :patch,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}",
        { owner_id: user_id }.to_json,
        Authorization: auth,
        content_type: :json,
        'X-Audit-Log-Reason': reason
      )
    end

    # Delete a server
    # https://discordapp.com/developers/docs/resources/guild#delete-guild
    def delete(auth, server_id)
      MijDiscord::Core::API.request(
        :guilds_sid,
        server_id,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}",
        Authorization: auth
      )
    end

    # Get a server's channels list
    # https://discordapp.com/developers/docs/resources/guild#get-guild-channels
    def channels(auth, server_id)
      MijDiscord::Core::API.request(
        :guilds_sid_channels,
        server_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/channels",
        Authorization: auth
      )
    end

    # Create a channel
    # https://discordapp.com/developers/docs/resources/guild#create-guild-channel
    def create_channel(auth, server_id, name, type, bitrate, user_limit, permissions, nsfw, reason = nil)
      MijDiscord::Core::API.request(
        :guilds_sid_channels,
        server_id,
        :post,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/channels",
        { name: name, type: type, bitrate: bitrate, user_limit: user_limit, permission_overwrites: permissions, nsfw: nsfw }.to_json,
        Authorization: auth,
        content_type: :json,
        'X-Audit-Log-Reason': reason
      )
    end

    # Update a channels position
    # https://discordapp.com/developers/docs/resources/guild#modify-guild-channel
    def update_channel_position(auth, server_id, channel_id, position, reason = nil)
      MijDiscord::Core::API.request(
        :guilds_sid_channels,
        server_id,
        :patch,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/channels",
        { id: channel_id, position: position }.to_json,
        Authorization: auth,
        content_type: :json,
        'X-Audit-Log-Reason': reason
      )
    end

    # Get a member's data
    # https://discordapp.com/developers/docs/resources/guild#get-guild-member
    def resolve_member(auth, server_id, user_id)
      MijDiscord::Core::API.request(
        :guilds_sid_members_uid,
        server_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/members/#{user_id}",
        Authorization: auth
      )
    end

    # Gets members from the server
    # https://discordapp.com/developers/docs/resources/guild#list-guild-members
    def resolve_members(auth, server_id, limit, after = nil)
      MijDiscord::Core::API.request(
        :guilds_sid_members,
        server_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/members?limit=#{limit}#{"&after=#{after}" if after}",
        Authorization: auth
      )
    end

    # Update a user properties
    # https://discordapp.com/developers/docs/resources/guild#modify-guild-member
    def update_member(auth, server_id, user_id, reason = nil, nick: nil, roles: nil, mute: nil, deaf: nil, channel_id: nil)
      MijDiscord::Core::API.request(
        :guilds_sid_members_uid,
        server_id,
        :patch,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/members/#{user_id}",
        { roles: roles, nick: nick, mute: mute, deaf: deaf, channel_id: channel_id }.delete_if {|_,v| v.nil? }.to_json,
        Authorization: auth,
        content_type: :json,
        'X-Audit-Log-Reason': reason
      )
    end

    # Remove user from server
    # https://discordapp.com/developers/docs/resources/guild#remove-guild-member
    def remove_member(auth, server_id, user_id, reason = nil)
      MijDiscord::Core::API.request(
        :guilds_sid_members_uid,
        server_id,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/members/#{user_id}",
        Authorization: auth,
        content_type: :json,
        'X-Audit-Log-Reason': reason
      )
    end

    # Get a server's banned users
    # https://discordapp.com/developers/docs/resources/guild#get-guild-bans
    def bans(auth, server_id)
      MijDiscord::Core::API.request(
        :guilds_sid_bans,
        server_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/bans",
        Authorization: auth
      )
    end

    # Ban a user from a server and delete their messages from the last message_days days
    # https://discordapp.com/developers/docs/resources/guild#create-guild-ban
    def ban_user(auth, server_id, user_id, message_days, reason = nil)
      MijDiscord::Core::API.request(
        :guilds_sid_bans_uid,
        server_id,
        :put,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/bans/#{user_id}?delete-message-days=#{message_days}",
        nil,
        Authorization: auth,
        'X-Audit-Log-Reason': reason
      )
    end

    # Unban a user from a server
    # https://discordapp.com/developers/docs/resources/guild#remove-guild-ban
    def unban_user(auth, server_id, user_id, reason = nil)
      MijDiscord::Core::API.request(
        :guilds_sid_bans_uid,
        server_id,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/bans/#{user_id}",
        Authorization: auth,
        'X-Audit-Log-Reason': reason
      )
    end

    # Get server roles
    # https://discordapp.com/developers/docs/resources/guild#get-guild-roles
    def roles(auth, server_id)
      MijDiscord::Core::API.request(
        :guilds_sid_roles,
        server_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/roles",
        Authorization: auth
      )
    end

    # Create a role (parameters such as name and colour if not set can be set by update_role afterwards)
    # Permissions are the Discord defaults; allowed: invite creation, reading/sending messages,
    # sending TTS messages, embedding links, sending files, reading the history, mentioning everybody,
    # connecting to voice, speaking and voice activity (push-to-talk isn't mandatory)
    # https://discordapp.com/developers/docs/resources/guild#get-guild-roles
    def create_role(auth, server_id, name, color, hoist, mentionable, permissions, reason = nil)
      MijDiscord::Core::API.request(
        :guilds_sid_roles,
        server_id,
        :post,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/roles",
        { color: color, name: name, hoist: hoist, mentionable: mentionable, permissions: permissions }.to_json,
        Authorization: auth,
        content_type: :json,
        'X-Audit-Log-Reason': reason
      )
    end

    # Update a role
    # Permissions are the Discord defaults; allowed: invite creation, reading/sending messages,
    # sending TTS messages, embedding links, sending files, reading the history, mentioning everybody,
    # connecting to voice, speaking and voice activity (push-to-talk isn't mandatory)
    # https://discordapp.com/developers/docs/resources/guild#modify-guild-role
    def update_role(auth, server_id, role_id, name, color, hoist, mentionable, permissions, reason = nil)
      MijDiscord::Core::API.request(
        :guilds_sid_roles_rid,
        server_id,
        :patch,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/roles/#{role_id}",
        {
          color: color, name: name, hoist: hoist,
          mentionable: mentionable, permissions: permissions
        }.delete_if {|_, v| v.nil? }.to_json,
        Authorization: auth,
        content_type: :json,
        'X-Audit-Log-Reason': reason
      )
    end

    # Delete a role
    # https://discordapp.com/developers/docs/resources/guild#delete-guild-role
    def delete_role(auth, server_id, role_id, reason = nil)
      MijDiscord::Core::API.request(
        :guilds_sid_roles_rid,
        server_id,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/roles/#{role_id}",
        Authorization: auth,
        'X-Audit-Log-Reason': reason
      )
    end

    # Adds a single role to a member
    # https://discordapp.com/developers/docs/resources/guild#add-guild-member-role
    def add_member_role(auth, server_id, user_id, role_id, reason = nil)
      MijDiscord::Core::API.request(
        :guilds_sid_members_uid_roles_rid,
        server_id,
        :put,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/members/#{user_id}/roles/#{role_id}",
        nil,
        Authorization: auth,
        'X-Audit-Log-Reason': reason
      )
    end

    # Removes a single role from a member
    # https://discordapp.com/developers/docs/resources/guild#remove-guild-member-role
    def remove_member_role(auth, server_id, user_id, role_id, reason = nil)
      MijDiscord::Core::API.request(
        :guilds_sid_members_uid_roles_rid,
        server_id,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/members/#{user_id}/roles/#{role_id}",
        Authorization: auth,
        'X-Audit-Log-Reason': reason
      )
    end

    # Get server prune count
    # https://discordapp.com/developers/docs/resources/guild#get-guild-prune-count
    def prune_count(auth, server_id, days)
      MijDiscord::Core::API.request(
        :guilds_sid_prune,
        server_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/prune?days=#{days}",
        Authorization: auth
      )
    end

    # Begin server prune
    # https://discordapp.com/developers/docs/resources/guild#begin-guild-prune
    def begin_prune(auth, server_id, days, reason = nil)
      MijDiscord::Core::API.request(
        :guilds_sid_prune,
        server_id,
        :post,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/prune",
        { days: days }.to_json,
        Authorization: auth,
        'X-Audit-Log-Reason': reason
      )
    end

    # Get invites from server
    # https://discordapp.com/developers/docs/resources/guild#get-guild-invites
    def invites(auth, server_id)
      MijDiscord::Core::API.request(
        :guilds_sid_invites,
        server_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/invites",
        Authorization: auth
      )
    end

    # Get server integrations
    # https://discordapp.com/developers/docs/resources/guild#get-guild-integrations
    def integrations(auth, server_id)
      MijDiscord::Core::API.request(
        :guilds_sid_integrations,
        server_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/integrations",
        Authorization: auth
      )
    end

    # Create a server integration
    # https://discordapp.com/developers/docs/resources/guild#create-guild-integration
    def create_integration(auth, server_id, type, id)
      MijDiscord::Core::API.request(
        :guilds_sid_integrations,
        server_id,
        :post,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/integrations",
        { type: type, id: id }.to_json,
        Authorization: auth
      )
    end

    # Update integration from server
    # https://discordapp.com/developers/docs/resources/guild#modify-guild-integration
    def update_integration(auth, server_id, integration_id, expire_behavior, expire_grace_period, enable_emoticons)
      MijDiscord::Core::API.request(
        :guilds_sid_integrations_iid,
        server_id,
        :patch,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/integrations/#{integration_id}",
        { expire_behavior: expire_behavior, expire_grace_period: expire_grace_period, enable_emoticons: enable_emoticons }.to_json,
        Authorization: auth,
        content_type: :json
      )
    end

    # Delete a server integration
    # https://discordapp.com/developers/docs/resources/guild#delete-guild-integration
    def delete_integration(auth, server_id, integration_id)
      MijDiscord::Core::API.request(
        :guilds_sid_integrations_iid,
        server_id,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/integrations/#{integration_id}",
        Authorization: auth
      )
    end

    # Sync an integration
    # https://discordapp.com/developers/docs/resources/guild#sync-guild-integration
    def sync_integration(auth, server_id, integration_id)
      MijDiscord::Core::API.request(
        :guilds_sid_integrations_iid_sync,
        server_id,
        :post,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/integrations/#{integration_id}/sync",
        nil,
        Authorization: auth
      )
    end

    # Adds a custom emoji
    def add_emoji(auth, server_id, image, name, reason = nil)
      MijDiscord::Core::API.request(
        :guilds_sid_emojis,
        server_id,
        :post,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/emojis",
        { image: image, name: name }.to_json,
        Authorization: auth,
        content_type: :json,
        'X-Audit-Log-Reason': reason
      )
    end

    # Changes an emoji name
    def edit_emoji(auth, server_id, emoji_id, name, reason = nil)
      MijDiscord::Core::API.request(
        :guilds_sid_emojis_eid,
        server_id,
        :patch,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/emojis/#{emoji_id}",
        { name: name }.to_json,
        Authorization: auth,
        content_type: :json,
        'X-Audit-Log-Reason': reason
      )
    end

    # Deletes a custom emoji
    def delete_emoji(auth, server_id, emoji_id, reason = nil)
      MijDiscord::Core::API.request(
        :guilds_sid_emojis_eid,
        server_id,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/emojis/#{emoji_id}",
        Authorization: auth,
        'X-Audit-Log-Reason': reason
      )
    end

    # Available voice regions for this server
    def regions(auth, server_id)
      MijDiscord::Core::API.request(
        :guilds_sid_regions,
        server_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/regions",
        Authorization: auth
      )
    end

    # Get server webhooks
    # https://discordapp.com/developers/docs/resources/webhook#get-guild-webhooks
    def webhooks(auth, server_id)
      MijDiscord::Core::API.request(
        :guilds_sid_webhooks,
        server_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/webhooks",
        Authorization: auth
      )
    end

    # Search messages (for userbots only)
    # Not officially documented, reverse engineered from tracking Discord's network activity
    def search_messages(auth, server_id, options)
      options = URI.encode_www_form(options)
      MijDiscord::Core::API.request(
        :guilds_guild_messages_search,
        server_id,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/messages/search?#{options}",
        Authorization: auth
      )
    end
  end
end