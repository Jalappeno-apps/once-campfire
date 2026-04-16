class CreateCallsInvites < ActiveRecord::Migration[8.2]
  def change
    create_table :calls_invites do |t|
      t.string :token, null: false
      t.text :destination_url, null: false
      t.references :room, null: false, foreign_key: true
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :calls_invites, :token, unique: true
    add_index :calls_invites, :expires_at
  end
end
