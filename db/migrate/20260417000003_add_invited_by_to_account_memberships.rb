class AddInvitedByToAccountMemberships < ActiveRecord::Migration[8.2]
  def change
    add_reference :account_memberships, :invited_by, foreign_key: { to_table: :users }
  end
end
