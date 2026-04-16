module Api
  module Mobile
    class BrandingsController < ApplicationController
      def show
        render json: {
          account_name: Current.account.name,
          logo_url: fresh_account_logo_url(size: :small),
          updated_at: Current.account.updated_at
        }
      end

      private
        def request_authentication
          head :unauthorized
        end
    end
  end
end
