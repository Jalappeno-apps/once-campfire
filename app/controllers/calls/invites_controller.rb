module Calls
  class InvitesController < ApplicationController
    allow_unauthenticated_access
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

    def show
      token = Calls::Invite.normalize_token(params[:token])
      invite = Calls::Invite.active.find_by!(token: token)
      redirect_to invite.destination_url, allow_other_host: true
    end

    private
      def render_not_found
        head :not_found
      end
  end
end
