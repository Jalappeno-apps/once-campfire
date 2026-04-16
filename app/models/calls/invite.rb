module Calls
  class Invite < ApplicationRecord
    self.table_name = "calls_invites"

    TOKEN_LENGTH = 8

    belongs_to :room
    belongs_to :creator, class_name: "User"

    validates :destination_url, presence: true
    validates :expires_at, presence: true
    validates :token, presence: true, uniqueness: true
    validate :destination_url_must_be_trusted

    scope :active, -> { where(expires_at: Time.current..) }

    before_validation :assign_token, on: :create

    class << self
      def normalize_token(raw_token)
        raw_token.to_s.unicode_normalize.gsub(/\p{Space}+/, "").downcase
      end

      def token_from_path(path)
        raw_token = path.to_s.match(%r{\A/(?:calls|c)/(?<token>[a-z0-9]+)}i) { |match| match[:token] }
        normalize_token(raw_token).presence
      end

      def trusted_destination_url(raw_url)
        uri = URI.parse(raw_url.to_s)
        return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        return nil unless Calls::Configuration.trusted_hosts.include?(uri.host)

        uri.to_s
      rescue URI::InvalidURIError
        nil
      end
    end

    def expired?
      expires_at <= Time.current
    end

    private
      def destination_url_must_be_trusted
        return if self.class.trusted_destination_url(destination_url).present?

        errors.add(:destination_url, "must use a trusted call host")
      end

      def assign_token
        self.token ||= generate_unique_token
      end

      def generate_unique_token
        loop do
          candidate = SecureRandom.alphanumeric(TOKEN_LENGTH).downcase
          break candidate unless self.class.exists?(token: candidate)
        end
      end
  end
end
