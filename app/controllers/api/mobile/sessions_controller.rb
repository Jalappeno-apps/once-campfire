module Api
  module Mobile
    class SessionsController < ApplicationController
      def show
        render json: {
          user_id: Current.user.id,
          name: Current.user.name
        }
      end

      private
        def request_authentication
          head :unauthorized
        end
    end
  end
end
