module Calls
  class MeetLinkBuilder
    ROOM_CONFIG_FRAGMENT = "config.prejoinConfig.enabled=false&config.visitors.enabled=false".freeze

    class << self
      def call(room:, creator: nil)
        slug = room_slug(room)
        token = Calls::JitsiTokenBuilder.call(room_slug: slug, creator: creator)
        query = token.present? ? "?#{URI.encode_www_form(jwt: token)}" : ""
        "#{Calls::Configuration.meet_base_url}/#{slug}#{query}##{ROOM_CONFIG_FRAGMENT}"
      end

      private
        def room_slug(room)
          timestamp = Time.current.to_i.to_s(36)
          suffix = SecureRandom.alphanumeric(6).downcase
          "daiwick-#{room.id}-#{timestamp}-#{suffix}"
        end
    end
  end
end
