# frozen_string_literal: true

module MijDiscord::Core::API::Invite
  class << self
    # Resolve an invite
    # https://discordapp.com/developers/docs/resources/invite#get-invite
    def resolve(token, invite_code)
      MijDiscord::Core::API.request(
        :invite_code,
        nil,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/invite/#{invite_code}",
        Authorization: token
      )
    end

    # Delete an invite by code
    # https://discordapp.com/developers/docs/resources/invite#delete-invite
    def delete(token, code, reason = nil)
      MijDiscord::Core::API.request(
        :invites_code,
        nil,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/invites/#{code}",
        Authorization: token,
        'X-Audit-Log-Reason': reason
      )
    end

    # Join a server using an invite
    # https://discordapp.com/developers/docs/resources/invite#accept-invite
    def accept(token, invite_code)
      MijDiscord::Core::API.request(
        :invite_code,
        nil,
        :post,
        "#{MijDiscord::Core::API::APIBASE_URL}/invite/#{invite_code}",
        nil,
        Authorization: token
      )
    end
  end
end