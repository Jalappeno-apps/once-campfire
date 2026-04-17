module Calls
  class InvitesController < ApplicationController
    allow_unauthenticated_access
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

    def show
      restore_authentication unless Current.user
      token = Calls::Invite.normalize_token(params[:token])
      invite = Calls::Invite.active.find_by!(token: token)
      destination_url = Calls::Invite.trusted_destination_url(invite.destination_url)
      return render_not_found unless destination_url

      head :found, location: redirect_destination(invite: invite, raw_url: destination_url)
    end

    private
      def redirect_destination(invite:, raw_url:)
        uri = URI.parse(raw_url)
        room_slug = uri.path.to_s.delete_prefix("/").split("/").first
        base_pairs = URI.decode_www_form(uri.query.to_s).reject { |key, _| key == "jwt" }
        jwt = member_jitsi_jwt_for(invite.room, room_slug)
        base_pairs << [ "jwt", jwt ] if jwt.present?

        uri.query = base_pairs.any? ? URI.encode_www_form(base_pairs) : nil
        uri.to_s
      rescue URI::InvalidURIError
        raw_url
      end

      def member_jitsi_jwt_for(room, room_slug)
        return nil unless Current.user
        return nil if room_slug.blank?
        return nil unless room.memberships.exists?(user_id: Current.user.id)

        Calls::JitsiTokenBuilder.call(room_slug: room_slug, creator: Current.user)
      end

      def render_not_found
        head :not_found
      end
  end
end
