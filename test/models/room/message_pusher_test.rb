require "test_helper"

class Room::MessagePusherTest < ActiveSupport::TestCase
  test "build_payload marks trusted call links as incoming calls" do
    message = rooms(:designers).messages.create!(
      body: "Join call: https://meet.jit.si/campfire-call-room",
      client_message_id: "message-pusher-call",
      creator: users(:david)
    )

    payload = Room::MessagePusher.new(room: rooms(:designers), message: message).send(:build_payload)

    assert_equal "incoming_call", payload[:type]
    assert_equal "https://meet.jit.si/campfire-call-room", payload[:call_url]
    assert_equal "David started a call", payload[:body]
  end

  test "targeted /meet only queues mentioned users for call notifications" do
    message = rooms(:designers).messages.create!(
      body: "<div>Join call: https://meet.jit.si/campfire-call-room #{mention_attachment_for(:kevin)}</div>",
      client_message_id: "message-pusher-targeted-call",
      creator: users(:david)
    )
    pusher = Room::MessagePusher.new(room: rooms(:designers), message: message)
    assert_includes message.mentionees.ids, users(:kevin).id

    pusher.expects(:push_to_targeted_call_users).once
    pusher.expects(:push_to_targeted_mobile_call_users).once
    pusher.expects(:push_to_users_involved_in_everything).never
    pusher.expects(:push_to_users_involved_in_mentions).never
    pusher.expects(:push_to_mobile_users_involved_in_everything).never
    pusher.expects(:push_to_mobile_users_involved_in_mentions).never

    pusher.push
  end
end
