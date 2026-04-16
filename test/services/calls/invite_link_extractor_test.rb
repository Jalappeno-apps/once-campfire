require "test_helper"

class Calls::InviteLinkExtractorTest < ActiveSupport::TestCase
  test "extracts trusted call links" do
    content = "Join call: https://meet.jit.si/campfire-room-123"

    assert_equal "https://meet.jit.si/campfire-room-123", Calls::InviteLinkExtractor.call(content)
  end

  test "ignores untrusted hosts" do
    content = "Join call: https://example.com/room"

    assert_nil Calls::InviteLinkExtractor.call(content)
  end
end
