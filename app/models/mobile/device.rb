module Mobile
  class Device < ApplicationRecord
    self.table_name = "mobile_devices"

    belongs_to :user

    scope :enabled, -> { where(enabled: true) }

    validates :expo_push_token, presence: true, uniqueness: true
  end
end
