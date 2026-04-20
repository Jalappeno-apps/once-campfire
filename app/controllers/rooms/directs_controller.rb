class Rooms::DirectsController < RoomsController
  before_action :set_room, only: %i[ edit destroy ]
  def new
    @room = Rooms::Direct.new
  end

  def create
    room = Rooms::Direct.find_or_create_for(selected_users, account: Current.account)

    broadcast_create_room(room)
    redirect_to room_url(room)
  end

  def edit
    @room_members = @room.users.many? ? @room.users.without(Current.user) : @room.users
    @last_message_at = @room.messages.maximum(:created_at)
  end

  private
    def selected_users
      Current.account.users.where(id: selected_users_ids.including(Current.user.id))
    end

    def selected_users_ids
      params.fetch(:user_ids, [])
    end

    def broadcast_create_room(room)
      room.memberships.each do |membership|
        membership.broadcast_prepend_to [ room.account, membership.user ], :rooms, target: :direct_rooms, partial: "users/sidebars/rooms/shared", locals: { membership: membership }
      end
    end

    # All users in a direct room can administer it
    def ensure_can_administer
      true
    end
end
