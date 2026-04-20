class User < ApplicationRecord
  include Avatar, Bannable, Bot, Mentionable, Role, Transferable

  attr_accessor :provisioning_account
  attribute :availability_status, :integer, default: 0

  has_many :account_memberships, dependent: :delete_all
  has_many :accounts, through: :account_memberships

  has_many :memberships, dependent: :delete_all
  has_many :rooms, through: :memberships

  has_many :reachable_messages, through: :rooms, source: :messages
  has_many :messages, dependent: :destroy, foreign_key: :creator_id

  has_many :push_subscriptions, class_name: "Push::Subscription", dependent: :delete_all
  has_many :mobile_devices, class_name: "Mobile::Device", dependent: :delete_all

  has_many :boosts, dependent: :destroy, foreign_key: :booster_id
  has_many :searches, dependent: :delete_all

  has_many :sessions, dependent: :destroy
  has_many :bans, dependent: :destroy

  enum :status, %i[ active deactivated banned ], default: :active
  enum :availability_status, { available: 0, away: 1, do_not_disturb: 2, invisible: 3 }, default: :available, prefix: :availability

  validates :custom_status, length: { maximum: 80 }
  validates :status_emoji, length: { maximum: 16 }

  has_secure_password validations: false

  after_create_commit :grant_membership_to_open_rooms

  scope :ordered, -> { order("LOWER(name)") }
  scope :filtered_by, ->(query) { where("name like ?", "%#{query}%") }

  def rooms_in_account(account)
    return Room.none unless account
    rooms.where(account_id: account.id)
  end

  def workspace_administrator?(account)
    account_memberships.find_by(account: account)&.administrator?
  end

  # Adds room memberships for every open channel in the workspace (idempotent).
  def grant_open_room_memberships_for_account(account)
    return unless account
    return if bot?

    open_room_ids = Room.opens.where(account_id: account.id).pluck(:id)
    return if open_room_ids.empty?

    have = memberships.where(room_id: open_room_ids).pluck(:room_id)
    missing_ids = open_room_ids - have
    return if missing_ids.empty?

    now = Time.current
    rows = missing_ids.map do |room_id|
      { room_id: room_id, user_id: id, involvement: "mentions", connections: 0, created_at: now, updated_at: now }
    end
    Membership.insert_all(rows)
  end

  def initials
    name.scan(/\b\w/).join
  end

  def title
    [ name, bio ].compact_blank.join(" – ")
  end

  def active_custom_status
    return unless custom_status.present?
    return if status_expires_at.present? && status_expires_at.past?

    [ status_emoji, custom_status ].compact_blank.join(" ")
  end

  def deactivate
    transaction do
      close_remote_connections

      memberships.without_direct_rooms.delete_all
      push_subscriptions.delete_all
      mobile_devices.delete_all
      searches.delete_all
      sessions.delete_all

      update! status: :deactivated, email_address: deactived_email_address
    end
  end

  def reset_remote_connections
    close_remote_connections reconnect: true
  end

  private
    def grant_membership_to_open_rooms
      account = provisioning_account || account_memberships.first&.account
      grant_open_room_memberships_for_account(account)
    end

    def deactived_email_address
      email_address&.gsub(/@/, "-deactivated-#{SecureRandom.uuid}@")
    end

    def close_remote_connections(reconnect: false)
      sessions.find_each do |session|
        ActionCable.server.remote_connections.where(current_session: session).disconnect reconnect: reconnect
      rescue ActionCable::RemoteConnections::RemoteConnection::InvalidIdentifiersError
        # Some test stubs and adapter combinations don't expose connection identifiers.
        nil
      end
    end
end
