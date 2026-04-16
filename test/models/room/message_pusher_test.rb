require "test_helper"

class Room::MessagePusherTest < ActiveSupport::TestCase
  test "build_payload marks trusted call links as incoming calls" do
    trusted_host = URI.parse(Calls::Configuration.meet_base_url).host
    message = rooms(:designers).messages.create!(
      body: "Join call: https://#{trusted_host}/campfire-call-room",
      client_message_id: "message-pusher-call",
      creator: users(:david)
    )

    payload = Room::MessagePusher.new(room: rooms(:designers), message: message).send(:build_payload)

    assert_equal "incoming_call", payload[:type]
    assert_equal "https://#{trusted_host}/campfire-call-room", payload[:call_url]
    assert_equal "David started a call", payload[:body]
  end

  test "targeted /meet only queues mentioned users for call notifications" do
    trusted_host = URI.parse(Calls::Configuration.meet_base_url).host
    message = rooms(:designers).messages.create!(
      body: "<div>Join call: https://#{trusted_host}/campfire-call-room #{mention_attachment_for(:kevin)}</div>",
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

  test "build_payload resolves short Campfire call links to trusted destination url" do
    invite = Calls::Invite.create!(
      room: rooms(:designers),
      creator: users(:david),
      destination_url: "https://meet.daiwick.com/campfire-call-room",
      expires_at: 1.hour.from_now
    )
    short_link = Rails.application.routes.url_helpers.short_call_invite_path(token: invite.token)
    message = rooms(:designers).messages.create!(
      body: "Join call: #{short_link}",
      client_message_id: "message-pusher-short-call-link",
      creator: users(:david)
    )

    payload = Room::MessagePusher.new(room: rooms(:designers), message: message).send(:build_payload)

    assert_equal "incoming_call", payload[:type]
    assert_equal invite.destination_url, payload[:call_url]
    assert_equal "David started a call", payload[:body]
  end

  test "scheduled meet links do not produce incoming call payload" do
    trusted_host = URI.parse(Calls::Configuration.meet_base_url).host
    message = rooms(:designers).messages.create!(
      body: "Scheduled call (2026-04-16 21:56): https://#{trusted_host}/campfire-call-room",
      client_message_id: "message-pusher-scheduled-call",
      creator: users(:david)
    )

    payload = Room::MessagePusher.new(room: rooms(:designers), message: message).send(:build_payload)

    assert_nil payload[:type]
    assert_nil payload[:call_url]
    assert_equal "Designers", payload[:title]
  end

end
