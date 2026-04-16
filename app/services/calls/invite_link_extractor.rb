module Calls
  module InviteLinkExtractor
    class << self
      def call(content)
        relative_short_link = extract_relative_short_link(content)
        return relative_short_link if relative_short_link

        URI.extract(content.to_s, %w[http https]).find do |candidate|
          trusted_call_link?(candidate) || short_call_link?(candidate)
        end
      end

      private
        def extract_relative_short_link(content)
          raw_match = content.to_s.match(%r{(/(?:calls|c)/[a-z0-9]+)}i)&.captures&.first
          token = Calls::Invite.token_from_path(raw_match)
          token.present? && Calls::Invite.active.exists?(token: token) ? "/c/#{token}" : nil
        end

        def trusted_call_link?(candidate)
          uri = URI.parse(candidate)
          Calls::Configuration.trusted_hosts.include?(uri.host)
        rescue URI::InvalidURIError
          false
        end

        def short_call_link?(candidate)
          uri = URI.parse(candidate)
          token = Calls::Invite.token_from_path(uri.path)
          token.present? && Calls::Invite.active.exists?(token: token)
        rescue URI::InvalidURIError
          false
        end
    end
  end
end
