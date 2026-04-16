class AddSingletonGuardToAccounts < ActiveRecord::Migration[8.2]
  def up
    add_column :accounts, :singleton_guard, :bigint
    say_with_time "backfill accounts.singleton_guard" do
      Account.reset_column_information
      Account.find_each do |a|
        a.update_column(:singleton_guard, a.id)
      end
    end
    change_column_null :accounts, :singleton_guard, false
    add_index :accounts, :singleton_guard, unique: true
  end

  def down
    remove_index :accounts, :singleton_guard
    remove_column :accounts, :singleton_guard
  end
end
