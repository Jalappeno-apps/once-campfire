require "test_helper"

class Calls::InviteLinkExtractorTest < ActiveSupport::TestCase
  test "extracts trusted call links" do
    trusted_host = URI.parse(Calls::Configuration.meet_base_url).host
    content = "Join call: https://#{trusted_host}/campfire-room-123"

    assert_equal "https://#{trusted_host}/campfire-room-123", Calls::InviteLinkExtractor.call(content)
  end

  test "ignores untrusted hosts" do
    content = "Join call: https://example.com/room"

    assert_nil Calls::InviteLinkExtractor.call(content)
  end

  test "extracts active Campfire short invite links" do
    invite = Calls::Invite.create!(
      room: rooms(:designers),
      creator: users(:david),
      destination_url: "https://meet.daiwick.com/campfire-room-123",
      expires_at: 10.minutes.from_now
    )
    content = "Join call: #{Rails.application.routes.url_helpers.short_call_invite_path(token: invite.token)}"

    assert_equal "/c/#{invite.token}", Calls::InviteLinkExtractor.call(content)
  end
end
