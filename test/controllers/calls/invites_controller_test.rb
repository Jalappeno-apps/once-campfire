require "test_helper"

class Calls::InvitesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "once.campfire.test"
  end

  test "redirects to destination for active invite token" do
    invite = Calls::Invite.create!(
      room: rooms(:designers),
      creator: users(:david),
      destination_url: "https://meet.daiwick.com/room-123?jwt=abc",
      expires_at: 30.minutes.from_now
    )

    get call_invite_url(token: invite.token)

    assert_redirected_to invite.destination_url
  end

  test "redirects via short /c route" do
    invite = Calls::Invite.create!(
      room: rooms(:designers),
      creator: users(:david),
      destination_url: "https://meet.daiwick.com/room-123?jwt=abc",
      expires_at: 30.minutes.from_now
    )

    get short_call_invite_url(token: invite.token)

    assert_redirected_to invite.destination_url
  end

  test "returns not found for unknown token" do
    get call_invite_url(token: "missingtoken")

    assert_response :not_found
  end

  test "returns not found for expired token" do
    invite = Calls::Invite.create!(
      room: rooms(:designers),
      creator: users(:david),
      destination_url: "https://meet.daiwick.com/room-123?jwt=abc",
      expires_at: 1.minute.ago
    )

    get call_invite_url(token: invite.token)

    assert_response :not_found
  end

  test "redirects when token contains trailing non-breaking space" do
    invite = Calls::Invite.create!(
      room: rooms(:designers),
      creator: users(:david),
      destination_url: "https://meet.daiwick.com/room-123?jwt=abc",
      expires_at: 30.minutes.from_now
    )

    get call_invite_url(token: "#{invite.token}\u00A0")

    assert_redirected_to invite.destination_url
  end
end
