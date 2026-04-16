module Calls
  module InviteLinkExtractor
    class << self
      def call(content)
        URI.extract(content.to_s, %w[http https]).find do |candidate|
          trusted_call_link?(candidate)
        end
      end

      private
        def trusted_call_link?(candidate)
          uri = URI.parse(candidate)
          Calls::Configuration.trusted_hosts.include?(uri.host)
        rescue URI::InvalidURIError
          false
        end
    end
  end
end
