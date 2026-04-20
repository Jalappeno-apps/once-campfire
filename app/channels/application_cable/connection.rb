module ApplicationCable
  class Connection < ActionCable::Connection::Base
    include Authentication::SessionLookup

    identified_by :current_user, :current_session

    def connect
      self.current_session = find_verified_session
      self.current_user = current_session.user
    end

    private
      def find_verified_session
        if verified_session = find_session_by_cookie
          verified_session
        else
          reject_unauthorized_connection
        end
      end
  end
end
