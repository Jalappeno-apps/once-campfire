require "test_helper"

class Rooms::OpenTest < ActiveSupport::TestCase
  test "grants access to all active human users after creation" do
    room = Rooms::Open.create!(name: "My open room with everyone!", creator: users(:david))
    assert_equal User.active.without_bots.count, room.users.count
  end

  test "grants access to all active human users after becoming open" do
    room = rooms(:watercooler).becomes!(Rooms::Open)
    room.save!
    assert_equal User.active.without_bots.count, room.users.without_bots.count
    assert room.users.bot.exists?
  end
end
