class Session < ApplicationRecord
  ACTIVITY_REFRESH_RATE = 2.minutes
  PRESENCE_REFRESH_RATE = 1.minute

  has_secure_token

  belongs_to :user
  belongs_to :account

  before_create { self.last_active_at ||= Time.now }

  def self.start!(user_agent:, ip_address:, account_id:)
    create! user_agent: user_agent, ip_address: ip_address, account_id: account_id
  end

  def resume(user_agent:, ip_address:)
    if last_active_at.before?(ACTIVITY_REFRESH_RATE.ago)
      update! user_agent: user_agent, ip_address: ip_address, last_active_at: Time.now
    end
  end

  def refresh_presence!
    return unless last_active_at.before?(PRESENCE_REFRESH_RATE.ago)

    update_columns(last_active_at: Time.current, updated_at: Time.current)
  end
end
