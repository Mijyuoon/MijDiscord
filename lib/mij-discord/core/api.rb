# frozen_string_literal: true

module MijDiscord::Core::API
  APIBASE_URL = 'https://discord.com/api/v6'

  CDN_URL = 'https://cdn.discordapp.com'

  class << self
    def user_agent(auth)
      case auth&.type
        when :bot
          bot_name = auth.name || 'generic'
          ua_base = "DiscordBot (https://github.com/Mijyuoon/mij-discord, v#{MijDiscord::VERSION})"
          "#{ua_base} mij-discord/#{MijDiscord::VERSION} #{bot_name}"

        when :user
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:78.0) Gecko/20100101 Firefox/78.0'
      end
    end

    # Make an icon URL from server and icon IDs
    def icon_url(server_id, icon_id, format = :png)
      "#{CDN_URL}/icons/#{server_id}/#{icon_id}.#{format}"
    end

    # Make an icon URL from application and icon IDs
    def app_icon_url(app_id, icon_id, format = :png)
      "#{CDN_URL}/app-icons/#{app_id}/#{icon_id}.#{format}"
    end

    # Make a widget picture URL from server ID
    def widget_url(server_id, style = 'shield')
      "#{APIBASE_URL}/guilds/#{server_id}/widget.png?style=#{style}"
    end

    # Make a splash URL from server and splash IDs
    def splash_url(server_id, splash_id)
      "#{CDN_URL}{/splashes/#{server_id}/#{splash_id}.jpg"
    end

    # Make an emoji icon URL from emoji ID
    def emoji_icon_url(emoji_id, format = :png)
      "#{CDN_URL}/emojis/#{emoji_id}.#{format}"
    end

    # Login to the server
    def login(email, password)
      request(
        :auth_login,
        nil,
        :post,
        "#{APIBASE_URL}/auth/login",
        email: email,
        password: password
      )
    end

    # Logout from the server
    def logout(auth)
      request(
        :auth_logout,
        nil,
        :post,
        "#{APIBASE_URL}/auth/logout",
        nil,
        Authorization: auth
      )
    end

    # Create an OAuth application
    def create_oauth_application(auth, name, redirect_uris)
      request(
        :oauth2_applications,
        nil,
        :post,
        "#{APIBASE_URL}/oauth2/applications",
        { name: name, redirect_uris: redirect_uris }.to_json,
        Authorization: auth,
        content_type: :json
      )
    end

    # Change an OAuth application's properties
    def update_oauth_application(auth, name, redirect_uris, description = '', icon = nil)
      request(
        :oauth2_applications,
        nil,
        :put,
        "#{APIBASE_URL}/oauth2/applications",
        { name: name, redirect_uris: redirect_uris, description: description, icon: icon }.to_json,
        Authorization: auth,
        content_type: :json
      )
    end

    # Get the bot's OAuth application's information
    def oauth_application(auth)
      request(
        :oauth2_applications_me,
        nil,
        :get,
        "#{APIBASE_URL}/oauth2/applications/@me",
        Authorization: auth
      )
    end

    # Acknowledge that a message has been received
    # The last acknowledged message will be sent in the ready packet,
    # so this is an easy way to catch up on messages
    def acknowledge_message(auth, channel_id, message_id)
      request(
        :channels_cid_messages_mid_ack,
        nil, # This endpoint is unavailable for bot accounts and thus isn't subject to its rate limit requirements.
        :post,
        "#{APIBASE_URL}/channels/#{channel_id}/messages/#{message_id}/ack",
        nil,
        Authorization: auth
      )
    end

    # Get the gateway to be used
    def gateway(auth)
      request(
        :gateway,
        nil,
        :get,
        "#{APIBASE_URL}/gateway",
        Authorization: auth,
      )
    end

    # Validate a token (this request will fail if the token is invalid)
    def validate_token(auth)
      request(
        :auth_login,
        nil,
        :post,
        "#{APIBASE_URL}/auth/login",
        {}.to_json,
        Authorization: auth,
        content_type: :json
      )
    end

    # Get a list of available voice regions
    def voice_regions(auth)
      request(
        :voice_regions,
        nil,
        :get,
        "#{APIBASE_URL}/voice/regions",
        Authorization: auth,
        content_type: :json
      )
    end

    def raw_request(type, *attributes)
      RestClient.send(type, *attributes)
    rescue RestClient::RequestFailed => e
      # Holy fuck, Discord…
      if (klazz = MijDiscord::Errors::HTTP_ERRORS[e.http_code])
        data = JSON.parse(e.response)
        if data['message'] || data['code']
          raise klazz.new(data['code'], data['message'], e.response)
        elsif (error = (data['content'] || data['embed'])&.join)
          if MijDiscord::Errors::MessageTooLong.match_pattern?(error)
            raise MijDiscord::Errors::MessageTooLong.new(error, e.response)
          end
        end
      end
      raise
    rescue RestClient::BadGateway
      MijDiscord::LOGGER.warn('HTTP') { 'Received 502 Bad Gateway during API request' }
      retry
    end

    def request(key, major_param, type, *attributes)
      ratelimit_delta, response = nil, nil

      if (params = attributes.last).is_a?(Hash)
        params[:user_agent] = user_agent(params[:Authorization])
        ratelimit_delta = params.delete(:header_bypass_delay)
      end

      key = [key, major_param].freeze
      key_mutex = (@rate_limit_mutex[key] ||= Mutex.new)
      global_mutex = @rate_limit_mutex[:global]

      begin
        mutex_wait(key_mutex)
        mutex_wait(global_mutex) if global_mutex.locked?

        response = raw_request(type, *attributes)
      rescue RestClient::TooManyRequests => e
        response = e.response

        is_global = response.headers[:x_ratelimit_global]
        mutex = is_global == 'true' ? global_mutex : key_mutex

        unless mutex.locked?
          response = JSON.parse(e.response)
          retry_after = response['retry_after'].to_i / 1000.0

          MijDiscord::LOGGER.info('HTTP') { "Hit Discord rate limit on <#{key}>, waiting for #{retry_after} seconds" }
          sync_wait(retry_after, mutex)
        end

        retry
      rescue RestClient::Exception => e
        response = e.response
        raise
      ensure
        headers = response&.headers
        if headers && headers[:x_ratelimit_remaining] == '0' && !key_mutex.locked?
          unless ratelimit_delta
            now = Time.rfc2822(headers[:date])
            reset = Time.at(headers[:x_ratelimit_reset].to_i)
            ratelimit_delta = reset - now
          end

          sync_wait(ratelimit_delta, key_mutex)
        end
      end

      response
    end

    private

    def sync_wait(time, mutex)
      mutex.synchronize { sleep(time) }
    end

    def mutex_wait(mutex)
      mutex.lock
      mutex.unlock
    end
  end

  # Initialize rate limit mutexes
  @rate_limit_mutex = { global: Mutex.new }
end
