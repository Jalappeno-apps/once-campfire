require "test_helper"

class Api::Mobile::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "show requires authentication" do
    get api_mobile_session_url, as: :json

    assert_response :unauthorized
  end

  test "show returns current user profile" do
    sign_in :david

    get api_mobile_session_url, as: :json

    assert_response :success
    assert_equal users(:david).id, response.parsed_body["user_id"]
    assert_equal users(:david).name, response.parsed_body["name"]
  end
end
