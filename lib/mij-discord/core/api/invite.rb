# frozen_string_literal: true

module MijDiscord::Core::API::Invite
  class << self
    # Resolve an invite
    # https://discordapp.com/developers/docs/resources/invite#get-invite
    def resolve(auth, invite_code, with_counts = false)
      counts = with_counts ? '?with_counts=true' : ''
      MijDiscord::Core::API.request(
        :invite_code,
        nil,
        :get,
        "#{MijDiscord::Core::API::APIBASE_URL}/invites/#{invite_code}#{counts}",
        Authorization: auth
      )
    end

    # Delete an invite by code
    # https://discordapp.com/developers/docs/resources/invite#delete-invite
    def delete(auth, code, reason = nil)
      MijDiscord::Core::API.request(
        :invites_code,
        nil,
        :delete,
        "#{MijDiscord::Core::API::APIBASE_URL}/invites/#{code}",
        Authorization: auth,
        'X-Audit-Log-Reason': reason
      )
    end

    # Join a server using an invite
    # https://discordapp.com/developers/docs/resources/invite#accept-invite
    def accept(auth, invite_code)
      MijDiscord::Core::API.request(
        :invite_code,
        nil,
        :post,
        "#{MijDiscord::Core::API::APIBASE_URL}/invites/#{invite_code}",
        nil,
        Authorization: auth
      )
    end
  end
end