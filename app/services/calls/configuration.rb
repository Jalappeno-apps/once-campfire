module Calls
  module Configuration
    DEFAULT_MEET_BASE_URL = "https://meet.daiwick.com".freeze
    DEFAULT_JITSI_JWT_AUDIENCE = "jitsi".freeze
    DEFAULT_TOKEN_TTL_SECONDS = 2.hours.to_i

    class << self
      def meet_base_url
        normalize_meet_base_url(ENV["MEET_BASE_URL"])
      end

      def trusted_hosts
        [ URI.parse(meet_base_url).host ].compact.uniq
      rescue URI::InvalidURIError
        [ URI.parse(DEFAULT_MEET_BASE_URL).host ]
      end

      def jitsi_jwt_app_id
        ENV["JITSI_JWT_APP_ID"].to_s.strip.presence
      end

      def jitsi_jwt_app_secret
        ENV["JITSI_JWT_APP_SECRET"].to_s.strip.presence
      end

      def jitsi_jwt_audience
        ENV["JITSI_JWT_AUDIENCE"].to_s.strip.presence || DEFAULT_JITSI_JWT_AUDIENCE
      end

      def jitsi_jwt_subject
        ENV["JITSI_JWT_SUBJECT"].to_s.strip.presence || URI.parse(meet_base_url).host
      rescue URI::InvalidURIError
        URI.parse(DEFAULT_MEET_BASE_URL).host
      end

      def jitsi_jwt_ttl_seconds
        raw_value = ENV["JITSI_JWT_TTL_SECONDS"].to_s.strip
        value = raw_value.to_i
        value.positive? ? value : DEFAULT_TOKEN_TTL_SECONDS
      end

      def jwt_enabled?
        jitsi_jwt_app_id.present? && jitsi_jwt_app_secret.present?
      end

      private
        def normalize_meet_base_url(raw_value)
          raw_url = raw_value.presence || DEFAULT_MEET_BASE_URL
          with_scheme = raw_url.match?(%r{\Ahttps?://}i) ? raw_url : "https://#{raw_url}"
          uri = URI.parse(with_scheme)

          return DEFAULT_MEET_BASE_URL unless uri.host.present?

          uri.path = ""
          uri.query = nil
          uri.fragment = nil
          uri.to_s.delete_suffix("/")
        rescue URI::InvalidURIError
          DEFAULT_MEET_BASE_URL
        end
    end
  end
end
