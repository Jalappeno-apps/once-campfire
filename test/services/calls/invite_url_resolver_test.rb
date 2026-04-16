require "test_helper"

class Calls::InviteUrlResolverTest < ActiveSupport::TestCase
  test "returns trusted call urls unchanged" do
    url = "https://meet.daiwick.com/campfire-room"

    assert_equal url, Calls::InviteUrlResolver.call(url)
  end

  test "resolves active short invite links to destination" do
    invite = Calls::Invite.create!(
      room: rooms(:designers),
      creator: users(:david),
      destination_url: "https://meet.daiwick.com/campfire-room",
      expires_at: 1.hour.from_now
    )
    url = Rails.application.routes.url_helpers.short_call_invite_path(token: invite.token)

    assert_equal invite.destination_url, Calls::InviteUrlResolver.call(url)
  end

  test "returns nil for expired short invite links" do
    invite = Calls::Invite.create!(
      room: rooms(:designers),
      creator: users(:david),
      destination_url: "https://meet.daiwick.com/campfire-room",
      expires_at: 1.minute.ago
    )
    url = Rails.application.routes.url_helpers.short_call_invite_path(token: invite.token)

    assert_nil Calls::InviteUrlResolver.call(url)
  end
end
