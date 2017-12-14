# frozen_string_literal: true

module MijDiscord::Core::API::User
  class << self
    # Get user data
    # https://discordapp.com/developers/docs/resources/user#get-user
    def resolve(auth, user_id)
      MijDiscord::Core::API.request(
        :users_uid,
        nil,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/users/#{user_id}",
        Authorization: auth
      )
    end

    # Get profile data (for userbots only)
    # Not officially documented, reverse engineered from tracking Discord's network activity
    def resolve2(auth, user_id)
      MijDiscord::Core::API.request(
        :users_uid,
        nil,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/users/#{user_id}/profile",
        Authorization: auth
      )
    end

    # Get current user data
    # https://discordapp.com/developers/docs/resources/user#get-current-user
    def profile(auth)
      MijDiscord::Core::API.request(
        :users_me,
        nil,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/users/@me",
        Authorization: auth
      )
    end

    # Change the current bot's nickname on a server
    def change_own_nickname(auth, server_id, nick, reason = nil)
      MijDiscord::Core::API.request(
        :guilds_sid_members_me_nick,
        server_id, # This is technically a guild endpoint
        :patch,
        "#{MijDiscord::Core::API::APIBASE_URL}/guilds/#{server_id}/members/@me/nick",
        { nick: nick }.to_json,
        Authorization: auth,
        content_type: :json,
        'X-Audit-Log-Reason': reason
      )
    end

    # Update user data
    # https://discordapp.com/developers/docs/resources/user#modify-current-user
    def update_profile(auth, username, avatar)
      MijDiscord::Core::API.request(
        :users_me,
        nil,
        :patch,
        "#{MijDiscord::Core::API::APIBASE_URL}/users/@me",
        { avatar: avatar, username: username }.delete_if {|_,v| v.nil? }.to_json,
        Authorization: auth,
        content_type: :json
      )
    end

    # Get the servers a user is connected to
    # https://discordapp.com/developers/docs/resources/user#get-current-user-guilds
    def servers(auth)
      MijDiscord::Core::API.request(
        :users_me_guilds,
        nil,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/users/@me/guilds",
        Authorization: auth
      )
    end

    # Leave a server
    # https://discordapp.com/developers/docs/resources/user#leave-guild
    def leave_server(auth, server_id)
      MijDiscord::Core::API.request(
        :users_me_guilds_sid,
        nil,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/users/@me/guilds/#{server_id}",
        Authorization: auth
      )
    end

    # Get the DMs for the current user
    # https://discordapp.com/developers/docs/resources/user#get-user-dms
    def user_dms(auth)
      MijDiscord::Core::API.request(
        :users_me_channels,
        nil,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/users/@me/channels",
        Authorization: auth
      )
    end

    # Create a DM to another user
    # https://discordapp.com/developers/docs/resources/user#create-dm
    def create_pm(auth, recipient_id)
      MijDiscord::Core::API.request(
        :users_me_channels,
        nil,
        :post,
        "#{MijDiscord::Core::API::APIBASE_URL}/users/@me/channels",
        { recipient_id: recipient_id }.to_json,
        Authorization: auth,
        content_type: :json
      )
    end

    # Get information about a user's connections
    # https://discordapp.com/developers/docs/resources/user#get-users-connections
    def connections(auth)
      MijDiscord::Core::API.request(
        :users_me_connections,
        nil,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/users/@me/connections",
        Authorization: auth
      )
    end

    # Change user status setting
    def change_status_setting(auth, status)
      MijDiscord::Core::API.request(
        :users_me_settings,
        nil,
        :patch,
        "#{MijDiscord::Core::API::APIBASE_URL}/users/@me/settings",
        { status: status }.to_json,
        Authorization: auth,
        content_type: :json
      )
    end

    # Returns one of the "default" discord avatars from the CDN given a discriminator
    def default_avatar(discrim = 0)
      "#{MijDiscord::Core::API::CDN_URL}/embed/avatars/#{discrim.to_i % 5}.png"
    end

    # Make an avatar URL from the user and avatar IDs
    def avatar_url(user_id, avatar_id, format = nil)
      format ||= avatar_id.start_with?('a_') ? :gif : :webp
      "#{MijDiscord::Core::API::CDN_URL}/avatars/#{user_id}/#{avatar_id}.#{format}"
    end
  end
end