module Calls
  module InviteUrlResolver
    class << self
      def call(raw_url)
        uri = URI.parse(raw_url.to_s)
        return uri.to_s if Calls::Configuration.trusted_hosts.include?(uri.host)

        token = Calls::Invite.token_from_path(uri.path)
        return nil unless token

        Calls::Invite.active.find_by(token: token)&.destination_url
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
