class Session < ApplicationRecord
  ACTIVITY_REFRESH_RATE = 1.hour

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
end
