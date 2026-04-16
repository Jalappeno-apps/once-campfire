require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "once.campfire.test"

    sign_in :david
    @room = rooms(:watercooler)
    @messages = @room.messages.ordered.to_a
  end

  test "index returns the last page by default" do
    get room_messages_url(@room)

    assert_response :success
    ensure_messages_present @messages.last
  end

  test "index returns a page before the specified message" do
    get room_messages_url(@room, before: @messages.third)

    assert_response :success
    ensure_messages_present @messages.first, @messages.second
    ensure_messages_not_present @messages.third, @messages.fourth, @messages.fifth
  end

  test "index returns a page after the specified message" do
    get room_messages_url(@room, after: @messages.third)

    assert_response :success
    ensure_messages_present @messages.fourth, @messages.fifth
    ensure_messages_not_present @messages.first, @messages.second, @messages.third
  end

  test "index returns no_content when there are no messages" do
    @room.messages.destroy_all

    get room_messages_url(@room)

    assert_response :no_content
  end

  test "get renders a single message belonging to the user" do
    message = @room.messages.where(creator: users(:david)).first

    get room_message_url(@room, message)

    assert_response :success
  end

  test "creating a message broadcasts the message to the room" do
    post room_messages_url(@room, format: :turbo_stream), params: { message: { body: "New one", client_message_id: 999 } }

    assert_rendered_turbo_stream_broadcast @room, :messages, action: "append", target: [ @room, :messages ] do
      assert_select ".message__body", text: /New one/
      assert_copy_link_button room_at_message_url(@room, Message.last, host: "once.campfire.test")
    end
  end

  test "creating a message broadcasts unread room" do
    assert_broadcasts "unread_rooms", 1 do
      post room_messages_url(@room, format: :turbo_stream), params: { message: { body: "New one", client_message_id: 999 } }
    end
  end

  test "creating a /meet message transforms into call invite link" do
    post room_messages_url(@room, format: :turbo_stream), params: { message: { body: "/meet", client_message_id: 999 } }

    message = Message.last
    assert_match(/\AJoin call: http:\/\/once\.campfire\.test\/c\/[a-z0-9]+[[:space:]\u00A0]*\z/, message.plain_text_body)
    invite = Calls::Invite.last
    assert_equal "Join call: #{short_call_invite_url(token: invite.token)}", message.plain_text_body
    assert_includes invite.destination_url, "-#{@room.id}-"
  end

  test "creating a /meet message transforms from rich-text html payload" do
    post room_messages_url(@room, format: :turbo_stream), params: {
      message: { body: "<div>/meet&nbsp;</div>", client_message_id: 999 }
    }

    message = Message.last
    assert_match(/\AJoin call: http:\/\/once\.campfire\.test\/c\/[a-z0-9]+[[:space:]\u00A0]*\z/, message.plain_text_body)
    assert_includes Calls::Invite.last.destination_url, "-#{@room.id}-"
  end

  test "creating a /meet message renders call invite action button" do
    post room_messages_url(@room, format: :turbo_stream), params: { message: { body: "/meet", client_message_id: 999 } }

    assert_rendered_turbo_stream_broadcast @room, :messages, action: "append", target: [ @room, :messages ] do
      assert_select ".message__call-invite", count: 1
      assert_select ".message__call-invite-btn", text: "Join call"
    end
  end

  test "creating a targeted /meet message preserves mention attachments" do
    post room_messages_url(@room, format: :turbo_stream), params: { message: {
      body: "<div>/meet #{mention_attachment_for(:jason)}</div>", client_message_id: 999
    } }

    message = Message.last
    assert_match(/\AJoin call: http:\/\/once\.campfire\.test\/c\/[a-z0-9]+ @Jason\z/, message.plain_text_body)
    assert_includes message.mentionees.ids, users(:jason).id
  end

  test "creating a scheduled /meet message keeps mention and external email participants" do
    post room_messages_url(@room, format: :turbo_stream), params: { message: {
      body: "<div>/meet at 2026-04-16 21:56 #{mention_attachment_for(:jason)} malhotraritwick2011@gmail.com</div>",
      client_message_id: 999
    } }

    message = Message.last
    assert_match(
      /\AScheduled call \(2026-04-16 21:56\): http:\/\/once\.campfire\.test\/c\/[a-z0-9]+ @Jason malhotraritwick2011@gmail.com\z/,
      message.plain_text_body
    )
    assert_includes message.mentionees.ids, users(:jason).id

    assert_rendered_turbo_stream_broadcast @room, :messages, action: "append", target: [ @room, :messages ] do
      assert_select ".message__call-invite-calendar", text: "Add to calendar"
      assert_select ".message__call-invite-calendar[href*='calendar.google.com']"
      assert_select ".message__call-invite-calendar[href*='location=']"
      assert_select ".message__call-invite-calendar[href*='%2Fc%2F']"
      assert_select ".message__call-invite-calendar[href*='dates=20260416T215600%2F20260416T225600']"
      assert_select ".message__call-invite-calendar[href*='add=jason%4037signals.com%2Cmalhotraritwick2011%40gmail.com']"
    end
  end

  test "update updates a message belonging to the user" do
    message = @room.messages.where(creator: users(:david)).first

    Turbo::StreamsChannel.expects(:broadcast_replace_to).once
    put room_message_url(@room, message), params: { message: { body: "Updated body" } }

    assert_redirected_to room_message_url(@room, message)
    assert_equal "Updated body", message.reload.plain_text_body
  end

  test "admin updates a message belonging to another user" do
    message = @room.messages.where(creator: users(:jason)).first

    Turbo::StreamsChannel.expects(:broadcast_replace_to).once
    put room_message_url(@room, message), params: { message: { body: "Updated body" } }

    assert_redirected_to room_message_url(@room, message)
    assert_equal "Updated body", message.reload.plain_text_body
  end

  test "destroy destroys a message belonging to the user" do
    message = @room.messages.where(creator: users(:david)).first

    assert_difference -> { Message.count }, -1 do
      Turbo::StreamsChannel.expects(:broadcast_remove_to).once
      delete room_message_url(@room, message, format: :turbo_stream)
      assert_response :success
    end
  end

  test "admin destroy destroys a message belonging to another user" do
    assert users(:david).administrator?
    message = @room.messages.where(creator: users(:jason)).first

    assert_difference -> { Message.count }, -1 do
      Turbo::StreamsChannel.expects(:broadcast_remove_to).once
      delete room_message_url(@room, message, format: :turbo_stream)
      assert_response :success
    end
  end

  test "ensure non-admin can't update a message belonging to another user" do
    sign_in :jz
    assert_not users(:jz).administrator?

    room = rooms(:designers)
    message = room.messages.where(creator: users(:jason)).first

    put room_message_url(room, message), params: { message: { body: "Updated body" } }
    assert_response :forbidden
  end

  test "ensure non-admin can't destroy a message belonging to another user" do
    sign_in :jz
    assert_not users(:jz).administrator?

    room = rooms(:designers)
    message = room.messages.where(creator: users(:jason)).first

    delete room_message_url(room, message, format: :turbo_stream)
    assert_response :forbidden
  end

  test "mentioning a bot triggers a webhook" do
    WebMock.stub_request(:post, webhooks(:bender).url).to_return(status: 200)

    assert_enqueued_jobs 1, only: Bot::WebhookJob do
      post room_messages_url(@room, format: :turbo_stream), params: { message: {
        body: "<div>Hey #{mention_attachment_for(:bender)}</div>", client_message_id: 999 } }
    end
  end

  private
    def ensure_messages_present(*messages, count: 1)
      messages.each do |message|
        assert_select "#" + dom_id(message), count:
      end
    end

    def ensure_messages_not_present(*messages)
      ensure_messages_present *messages, count: 0
    end

    def assert_copy_link_button(url)
      assert_select ".btn[title='Copy link'][data-copy-to-clipboard-content-value='#{url}']"
    end
end
