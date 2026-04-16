class CreateMobileDevices < ActiveRecord::Migration[8.2]
  def change
    create_table :mobile_devices do |t|
      t.references :user, null: false, foreign_key: true
      t.string :expo_push_token, null: false
      t.string :platform, null: false, default: "unknown"
      t.string :device_name
      t.datetime :last_seen_at
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    add_index :mobile_devices, :expo_push_token, unique: true
  end
end
