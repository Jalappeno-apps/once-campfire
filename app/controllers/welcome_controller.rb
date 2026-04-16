class WelcomeController < ApplicationController
  def show
    if Current.user.rooms_in_account(Current.account).any?
      redirect_to room_url(last_room_visited)
    else
      render
    end
  end
end
