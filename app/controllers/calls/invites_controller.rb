module Calls
  class InvitesController < ApplicationController
    allow_unauthenticated_access
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

    def show
      token = Calls::Invite.normalize_token(params[:token])
      invite = Calls::Invite.active.find_by!(token: token)
      destination_url = Calls::Invite.trusted_destination_url(invite.destination_url)
      return render_not_found unless destination_url

      head :found, location: destination_url
    end

    private
      def render_not_found
        head :not_found
      end
  end
end
