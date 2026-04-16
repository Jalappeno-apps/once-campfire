class Users::SidebarsController < ApplicationController
  DIRECT_PLACEHOLDERS = 20

  def show
    all_memberships = Current.user.memberships.visible.with_ordered_room
      .joins(:room).where(rooms: { account_id: Current.account.id })
      .includes(room: [ :users, { memberships: :user } ])
    direct_memberships = all_memberships.select { |m| m.room.direct? }
    @direct_memberships = extract_direct_memberships(direct_memberships)
    @channel_memberships = all_memberships.without(direct_memberships).to_a
    @sidebar_bots       = User.active_bots.joins(:account_memberships).where(account_memberships: { account_id: Current.account.id }).ordered
    @sidebar_bot_chat_rooms = build_sidebar_bot_chat_rooms(direct_memberships)

    @direct_placeholder_users = find_direct_placeholder_users
  end

  private
    def extract_direct_memberships(direct_memberships)
      direct_memberships.reject { |m| m.room.direct_only_bots_besides?(Current.user) }
        .sort_by { |m| m.room.updated_at }
        .reverse
    end

    def build_sidebar_bot_chat_rooms(direct_memberships)
      direct_memberships.each_with_object({}) do |m, rooms_by_bot_id|
        next unless m.room.direct_only_bots_besides?(Current.user)

        m.room.users.each do |u|
          next if u.id == Current.user.id || !u.bot?

          rooms_by_bot_id[u.id] = m.room
        end
      end
    end

    def find_direct_placeholder_users
      exclude_user_ids = user_ids_already_in_direct_rooms_with_current_user.including(Current.user.id)
      scope = Current.account.users.active.where.not(id: exclude_user_ids)
      inviter_id = Current.user.account_memberships.find_by(account: Current.account)&.invited_by_id
      scope =
        if inviter_id.present? && scope.exists?(id: inviter_id)
          scope.order(
            Arel.sql("CASE WHEN users.id = #{User.connection.quote(inviter_id)} THEN 0 ELSE 1 END"),
            :created_at
          )
        else
          scope.order(:created_at)
        end
      scope.limit([ DIRECT_PLACEHOLDERS - exclude_user_ids.count, 0 ].max)
    end

    def user_ids_already_in_direct_rooms_with_current_user
      Membership.where(room_id: Current.user.rooms_in_account(Current.account).directs.select(:id)).pluck(:user_id).uniq
    end
end
