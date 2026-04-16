class Account < ApplicationRecord
  include Joinable

  has_one_attached :logo
  has_json :settings, restrict_room_creation_to_administrators: false

  has_many :account_memberships, dependent: :delete_all
  has_many :users, through: :account_memberships
  has_many :rooms, dependent: :destroy

  before_validation :assign_singleton_guard_if_missing, on: :create

  # `singleton_guard` is unique per row. First-run provisioning uses 0 (only one row may use it).
  def self.next_unique_singleton_guard
    loop do
      n = SecureRandom.random_number(2**62) + 1
      return n unless exists?(singleton_guard: n)
    end
  end

  private
    def assign_singleton_guard_if_missing
      self.singleton_guard = self.class.next_unique_singleton_guard if singleton_guard.nil?
    end
end
