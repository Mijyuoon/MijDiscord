# frozen_string_literal: true

module MijDiscord::Core::API::Webhook
  class << self
    # Get a webhook
    # https://discordapp.com/developers/docs/resources/webhook#get-webhook
    def webhook(auth, webhook_id)
      MijDiscord::Core::API.request(
        :webhooks_wid,
        nil,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/webhooks/#{webhook_id}",
        Authorization: auth
      )
    end

    # Get a webhook via webhook token
    # https://discordapp.com/developers/docs/resources/webhook#get-webhook-with-token
    def token_webhook(webhook_token, webhook_id)
      MijDiscord::Core::API.request(
        :webhooks_wid,
        nil,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/webhooks/#{webhook_id}/#{webhook_token}",
      )
    end

    # Update a webhook
    # https://discordapp.com/developers/docs/resources/webhook#modify-webhook
    def update_webhook(auth, webhook_id, data, reason = nil)
      MijDiscord::Core::API.request(
        :webhooks_wid,
        webhook_id,
        :patch,
        "#{MijDiscord::Core::API::APIBASE_URL}/webhooks/#{webhook_id}",
        data.to_json,
        Authorization: auth,
        content_type: :json,
        'X-Audit-Log-Reason': reason,
      )
    end

    # Update a webhook via webhook token
    # https://discordapp.com/developers/docs/resources/webhook#modify-webhook-with-token
    def token_update_webhook(webhook_token, webhook_id, data, reason = nil)
      MijDiscord::Core::API.request(
        :webhooks_wid,
        webhook_id,
        :patch,
        "#{MijDiscord::Core::API::APIBASE_URL}/webhooks/#{webhook_id}/#{webhook_token}",
        data.to_json,
        content_type: :json,
        'X-Audit-Log-Reason': reason,
      )
    end

    # Deletes a webhook
    # https://discordapp.com/developers/docs/resources/webhook#delete-webhook
    def delete_webhook(auth, webhook_id, reason = nil)
      MijDiscord::Core::API.request(
        :webhooks_wid,
        webhook_id,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/webhooks/#{webhook_id}",
        Authorization: auth,
        'X-Audit-Log-Reason': reason,
      )
    end

    # Deletes a webhook via webhook token
    # https://discordapp.com/developers/docs/resources/webhook#delete-webhook-with-token
    def token_delete_webhook(webhook_token, webhook_id, reason = nil)
      MijDiscord::Core::API.request(
        :webhooks_wid,
        webhook_id,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/webhooks/#{webhook_id}/#{webhook_token}",
        'X-Audit-Log-Reason': reason,
      )
    end

    # Executes a webhook with JSON body
    # https://discordapp.com/developers/docs/resources/webhook#execute-webhook
    def execute_json(webhook_token, webhook_id, data, wait)
      wait = wait ? '?wait=true' : ''
      MijDiscord::Core::API.raw_request(
        :post,
        "#{MijDiscord::Core::API::APIBASE_URL}/webhooks/#{webhook_id}/#{webhook_token}#{wait}",
        data.to_json,
        content_type: :json,
      )
    end
  end
end