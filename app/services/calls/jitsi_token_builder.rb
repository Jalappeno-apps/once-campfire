module Calls
  class JitsiTokenBuilder
    class << self
      def call(room_slug:, creator:)
        return nil unless Calls::Configuration.jwt_enabled?

        JWT.encode(payload(room_slug:, creator:), Calls::Configuration.jitsi_jwt_app_secret, "HS256", { typ: "JWT" })
      rescue StandardError => error
        Rails.logger.error("Jitsi token generation failed error=#{error.class} message=#{error.message}")
        nil
      end

      private
        def payload(room_slug:, creator:)
          now = Time.current.to_i

          {
            aud: Calls::Configuration.jitsi_jwt_audience,
            iss: Calls::Configuration.jitsi_jwt_app_id,
            sub: Calls::Configuration.jitsi_jwt_subject,
            room: room_slug,
            exp: now + Calls::Configuration.jitsi_jwt_ttl_seconds,
            nbf: now - 10,
            context: {
              user: {
                id: creator&.id&.to_s,
                name: creator&.name.to_s.presence || "Campfire user"
              }.compact
            }
          }
        end
    end
  end
end
