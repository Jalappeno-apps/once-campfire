require "test_helper"

class Users::SidebarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
  end

  test "show" do
    get user_sidebar_url

    assert_select ".sidebar-group__header", text: /Direct messages/
    assert_select ".sidebar-group__header", text: /Channels/
    assert_select ".sidebar-group__header", text: /Chat bots/
    assert_select ".rooms__search-field", text: /Search/
  end

  test "closed rooms with bot members appear under channels like other channels" do
    get user_sidebar_url

    bot_room_path = room_path(rooms(:watercooler))

    assert_select "#channel_rooms a[href='#{bot_room_path}']", count: 1
  end

  test "chat bot accounts are listed in the Chat bots section and open the bot DM" do
    chat_room = Current.set(user: users(:david)) { Rooms::Direct.find_or_create_for([ users(:david), users(:bender) ], account: accounts(:signal)) }

    get user_sidebar_url

    assert_select "#sidebar_bots_list a.sidebar-bot[href='#{room_path(chat_room)}']", count: 1
  end

  test "1:1 bot chats are not duplicated under Direct messages" do
    chat_room = Current.set(user: users(:david)) { Rooms::Direct.find_or_create_for([ users(:david), users(:bender) ], account: accounts(:signal)) }

    get user_sidebar_url

    assert_select "#direct_rooms a[href='#{room_path(chat_room)}']", count: 0
    assert_select "#sidebar_bots_list a[href='#{room_path(chat_room)}']", count: 1
  end

  test "open channels stay under channels when a bot user is a member" do
    rooms(:hq).memberships.create!(user: users(:bender), involvement: :everything)

    get user_sidebar_url

    hq_path = room_path(rooms(:hq))
    assert_select "#channel_rooms a[href='#{hq_path}']", count: 1
  end

  test "unread directs" do
    rooms(:david_and_jason).messages.create! client_message_id: 999, body: "Hello", creator: users(:jason)

    get user_sidebar_url
    assert_select ".unread", count: users(:david).memberships.select { |m| m.room.direct? && m.unread? }.count
  end


  test "unread other" do
    rooms(:watercooler).messages.create! client_message_id: 999, body: "Hello", creator: users(:jason)

    get user_sidebar_url
    assert_select ".unread", count: users(:david).memberships.reject { |m| m.room.direct? || !m.unread? }.count
  end
end
