require "test_helper"

class Calls::InviteTest < ActiveSupport::TestCase
  test "generates a unique token on create" do
    invite = Calls::Invite.create!(
      room: rooms(:designers),
      creator: users(:david),
      destination_url: "https://meet.daiwick.com/room-123",
      expires_at: 1.hour.from_now
    )

    assert_predicate invite.token, :present?
    assert_equal 8, invite.token.length
  end

  test "extracts token from call invite path" do
    assert_equal "abc123", Calls::Invite.token_from_path("/c/abc123")
    assert_equal "abc123", Calls::Invite.token_from_path("/calls/abc123")
    assert_nil Calls::Invite.token_from_path("/rooms/abc123")
  end

  test "normalizes token values with unicode spaces" do
    assert_equal "abc123", Calls::Invite.normalize_token(" abc123\u00A0")
    assert_equal "abc123", Calls::Invite.token_from_path("/c/abc123\u00A0")
    assert_equal "abc123", Calls::Invite.token_from_path("/calls/abc123\u00A0")
  end

  test "rejects untrusted destination host" do
    invite = Calls::Invite.new(
      room: rooms(:designers),
      creator: users(:david),
      destination_url: "https://example.com/room-123",
      expires_at: 1.hour.from_now
    )

    assert_not invite.valid?
    assert_includes invite.errors[:destination_url], "must use a trusted call host"
  end
end
