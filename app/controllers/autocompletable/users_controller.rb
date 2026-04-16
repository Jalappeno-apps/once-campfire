class Autocompletable::UsersController < ApplicationController
  def index
    set_page_and_extract_portion_from autocompletable_users_for_index, per_page: 20
  end

  private
    def autocompletable_users_for_index
      users = find_autocompletable_users.with_attached_avatar
      if params[:query].blank? && (inviter_id = dm_picker_invited_by_id)
        users.reorder(
          Arel.sql("CASE WHEN users.id = #{User.connection.quote(inviter_id)} THEN 0 ELSE 1 END"),
          Arel.sql("LOWER(users.name)")
        )
      else
        users.ordered
      end
    end

    def dm_picker_invited_by_id
      Current.user.account_memberships.find_by(account_id: Current.account.id)&.invited_by_id
    end

    def find_autocompletable_users
      params[:query].present? ? users_scope.active.filtered_by(params[:query]) : users_scope.active
    end

    def users_scope
      if params[:room_id].present?
        Current.user.rooms_in_account(Current.account).find(params[:room_id]).users
      else
        Current.account.users
      end
    end
end
