# Rooms open to all users on the account. When a new user is added to the account, they're automatically granted membership.
class Rooms::Open < Room
  after_save_commit :grant_access_to_all_users

  private
    def grant_access_to_all_users
      if type_previously_changed?(to: "Rooms::Open")
        memberships.grant_to(account.users.active.without_bots)
      end
    end
end
