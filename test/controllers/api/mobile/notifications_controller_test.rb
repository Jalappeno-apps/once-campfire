require "test_helper"

class Api::Mobile::NotificationsControllerTest < ActionDispatch::IntegrationTest
  test "index requires authentication" do
    get api_mobile_notifications_url, as: :json

    assert_response :unauthorized
  end

  test "index returns unread count for signed in user" do
    sign_in :david

    memberships(:david_hq).update!(unread_at: 2.minutes.ago)
    memberships(:david_designers).update!(unread_at: 1.minute.ago)

    get api_mobile_notifications_url, as: :json

    assert_response :success
    assert_equal 2, response.parsed_body["unread_count"]
    assert_equal [ rooms(:hq).id, rooms(:designers).id ].sort, response.parsed_body["unread_room_ids"].sort
  end
end
