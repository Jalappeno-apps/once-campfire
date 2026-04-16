class MultiWorkspace < ActiveRecord::Migration[8.2]
  def up
    remove_index :accounts, name: "index_accounts_on_singleton_guard"
    remove_column :accounts, :singleton_guard

    create_table :account_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.integer :role, null: false, default: 0
      t.timestamps
    end
    add_index :account_memberships, [ :user_id, :account_id ], unique: true

    add_reference :rooms, :account, foreign_key: true
    add_reference :sessions, :account, foreign_key: true

    legacy_account_id = Account.order(:id).first&.id
    raise ActiveRecord::MigrationError, "No account row to migrate" unless legacy_account_id

    say_with_time "backfill rooms.account_id" do
      Room.where(account_id: nil).update_all(account_id: legacy_account_id)
    end

    say_with_time "backfill account_memberships" do
      # User roles: member: 0, administrator: 1, bot: 2
      # AccountMembership: member: 0, administrator: 1
      rows = User.pluck(:id, :role).map do |user_id, role|
        am_role = (role == 1) ? 1 : 0
        now = Time.current
        { user_id: user_id, account_id: legacy_account_id, role: am_role, created_at: now, updated_at: now }
      end
      AccountMembership.insert_all(rows) if rows.any?
    end

    say_with_time "backfill sessions.account_id" do
      Session.where(account_id: nil).update_all(account_id: legacy_account_id)
    end

    change_column_null :rooms, :account_id, false
    change_column_null :sessions, :account_id, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
