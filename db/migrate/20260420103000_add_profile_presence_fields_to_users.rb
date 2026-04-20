class AddProfilePresenceFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :availability_status, :integer, default: 0, null: false
    add_column :users, :custom_status, :string
    add_column :users, :status_emoji, :string
    add_column :users, :status_expires_at, :datetime
  end
end
