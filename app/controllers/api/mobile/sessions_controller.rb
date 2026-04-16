module Api
  module Mobile
    class SessionsController < ApplicationController
      def show
        render json: {
          user_id: Current.user.id,
          name: Current.user.name,
          account_id: Current.account&.id,
          account_name: Current.account&.name,
          trusted_call_hosts: Calls::Configuration.trusted_hosts
        }
      end

      def destroy
        terminate_current_session
        head :ok
      end

      private
        def request_authentication
          head :unauthorized
        end
    end
  end
end
