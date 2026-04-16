class FirstRun
  ACCOUNT_NAME = "Campfire"
  FIRST_ROOM_NAME = "All Talk"

  def self.create!(user_params)
    account = Account.create!(name: ACCOUNT_NAME, singleton_guard: 0)
    room    = Rooms::Open.new(name: FIRST_ROOM_NAME, account: account)

    administrator = room.creator = User.new(user_params.merge(role: :administrator))
    administrator.provisioning_account = account
    room.save!

    AccountMembership.create!(user: administrator, account: account, role: :administrator)
    room.memberships.grant_to administrator

    administrator
  end
end
