module Api
  module Mobile
    class NotificationsController < ApplicationController
      def index
        memberships = Current.user.memberships.visible

        render json: {
          unread_count: memberships.unread.count,
          unread_room_ids: memberships.unread.pluck(:room_id)
        }
      end

      private
        # Mobile polling should receive an auth error response instead of a redirect
        # to the HTML sign-in page so the app can handle it cleanly.
        def request_authentication
          head :unauthorized
        end
    end
  end
end
