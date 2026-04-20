# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.2].define(version: 2026_04_20_103000) do
  create_table "account_memberships", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.integer "invited_by_id"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["account_id"], name: "index_account_memberships_on_account_id"
    t.index ["invited_by_id"], name: "index_account_memberships_on_invited_by_id"
    t.index ["user_id", "account_id"], name: "index_account_memberships_on_user_id_and_account_id", unique: true
    t.index ["user_id"], name: "index_account_memberships_on_user_id"
  end

  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "custom_styles"
    t.string "join_code", null: false
    t.string "name", null: false
    t.json "settings"
    t.bigint "singleton_guard", null: false
    t.datetime "updated_at", null: false
    t.index ["singleton_guard"], name: "index_accounts_on_singleton_guard", unique: true
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "bans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["ip_address"], name: "index_bans_on_ip_address"
    t.index ["user_id"], name: "index_bans_on_user_id"
  end

  create_table "boosts", force: :cascade do |t|
    t.integer "booster_id", null: false
    t.string "content", limit: 16, null: false
    t.datetime "created_at", null: false
    t.integer "message_id", null: false
    t.datetime "updated_at", null: false
    t.index ["booster_id"], name: "index_boosts_on_booster_id"
    t.index ["message_id"], name: "index_boosts_on_message_id"
  end

  create_table "calls_invites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.text "destination_url", null: false
    t.datetime "expires_at", null: false
    t.integer "room_id", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_calls_invites_on_creator_id"
    t.index ["expires_at"], name: "index_calls_invites_on_expires_at"
    t.index ["room_id"], name: "index_calls_invites_on_room_id"
    t.index ["token"], name: "index_calls_invites_on_token", unique: true
  end

  create_table "calls_session_targets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "responded_at"
    t.integer "session_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["session_id", "user_id"], name: "index_calls_session_targets_on_session_id_and_user_id", unique: true
    t.index ["session_id"], name: "index_calls_session_targets_on_session_id"
    t.index ["status"], name: "index_calls_session_targets_on_status"
    t.index ["user_id"], name: "index_calls_session_targets_on_user_id"
  end

  create_table "calls_sessions", force: :cascade do |t|
    t.datetime "accepted_at"
    t.integer "accepted_by_id"
    t.text "call_url", null: false
    t.integer "caller_id", null: false
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.datetime "expires_at", null: false
    t.integer "invite_id"
    t.integer "message_id"
    t.string "path"
    t.integer "room_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["accepted_by_id"], name: "index_calls_sessions_on_accepted_by_id"
    t.index ["caller_id"], name: "index_calls_sessions_on_caller_id"
    t.index ["expires_at"], name: "index_calls_sessions_on_expires_at"
    t.index ["invite_id"], name: "index_calls_sessions_on_invite_id"
    t.index ["message_id"], name: "index_calls_sessions_on_message_id"
    t.index ["room_id"], name: "index_calls_sessions_on_room_id"
    t.index ["status"], name: "index_calls_sessions_on_status"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "connected_at"
    t.integer "connections", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "involvement", default: "mentions"
    t.integer "room_id", null: false
    t.datetime "unread_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["room_id", "created_at"], name: "index_memberships_on_room_id_and_created_at"
    t.index ["room_id", "user_id"], name: "index_memberships_on_room_id_and_user_id", unique: true
    t.index ["room_id"], name: "index_memberships_on_room_id"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.string "client_message_id", null: false
    t.datetime "created_at", null: false
    t.integer "creator_id"
    t.integer "room_id", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_messages_on_creator_id"
    t.index ["room_id"], name: "index_messages_on_room_id"
  end

  create_table "mobile_devices", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "device_name"
    t.boolean "enabled", default: true, null: false
    t.string "expo_push_token", null: false
    t.datetime "last_seen_at"
    t.string "platform", default: "unknown", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["expo_push_token"], name: "index_mobile_devices_on_expo_push_token", unique: true
    t.index ["user_id"], name: "index_mobile_devices_on_user_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.string "auth_key"
    t.datetime "created_at", null: false
    t.string "endpoint"
    t.string "p256dh_key"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["endpoint", "p256dh_key", "auth_key"], name: "idx_on_endpoint_p256dh_key_auth_key_7553014576"
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.string "name"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_rooms_on_account_id"
  end

  create_table "searches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "query", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_searches_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "last_active_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["account_id"], name: "index_sessions_on_account_id"
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "availability_status", default: 0, null: false
    t.text "bio"
    t.string "bot_token"
    t.datetime "created_at", null: false
    t.string "custom_status"
    t.string "email_address"
    t.string "name", null: false
    t.string "password_digest"
    t.integer "role", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.string "status_emoji"
    t.datetime "status_expires_at"
    t.datetime "updated_at", null: false
    t.index ["bot_token"], name: "index_users_on_bot_token", unique: true
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "webhooks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_webhooks_on_user_id"
  end

  add_foreign_key "account_memberships", "accounts"
  add_foreign_key "account_memberships", "users"
  add_foreign_key "account_memberships", "users", column: "invited_by_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bans", "users"
  add_foreign_key "boosts", "messages"
  add_foreign_key "calls_invites", "rooms"
  add_foreign_key "calls_invites", "users", column: "creator_id"
  add_foreign_key "calls_session_targets", "calls_sessions", column: "session_id"
  add_foreign_key "calls_session_targets", "users"
  add_foreign_key "calls_sessions", "calls_invites", column: "invite_id"
  add_foreign_key "calls_sessions", "messages"
  add_foreign_key "calls_sessions", "rooms"
  add_foreign_key "calls_sessions", "users", column: "accepted_by_id"
  add_foreign_key "calls_sessions", "users", column: "caller_id"
  add_foreign_key "messages", "rooms"
  add_foreign_key "messages", "users", column: "creator_id"
  add_foreign_key "mobile_devices", "users"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "rooms", "accounts"
  add_foreign_key "searches", "users"
  add_foreign_key "sessions", "accounts"
  add_foreign_key "sessions", "users"
  add_foreign_key "webhooks", "users"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
  create_virtual_table "message_search_index", "fts5", ["body", "tokenize=porter"]
end
