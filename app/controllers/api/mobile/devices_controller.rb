module Api
  module Mobile
    class DevicesController < ApplicationController
      skip_forgery_protection

      def index
        render json: Current.user.mobile_devices.order(updated_at: :desc).as_json(only: %i[ id expo_push_token platform device_name last_seen_at enabled ])
      end

      def create
        device = ::Mobile::Device.find_or_initialize_by(expo_push_token: device_params[:expo_push_token])
        device.assign_attributes(device_params.except(:expo_push_token))
        device.user = Current.user
        device.enabled = true
        device.last_seen_at = Time.current
        device.save!

        render json: device.as_json(only: %i[ id expo_push_token platform device_name last_seen_at enabled ])
      end

      private
        def request_authentication
          head :unauthorized
        end

        def device_params
          params.require(:device).permit(:expo_push_token, :platform, :device_name)
        end
    end
  end
end
