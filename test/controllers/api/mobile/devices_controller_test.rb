require "test_helper"

class Api::Mobile::DevicesControllerTest < ActionDispatch::IntegrationTest
  test "index requires authentication" do
    get api_mobile_devices_url, as: :json

    assert_response :unauthorized
  end

  test "create stores mobile device for current user" do
    sign_in :david

    assert_difference -> { Mobile::Device.count }, 1 do
      post api_mobile_devices_url,
           params: { device: { expo_push_token: "ExponentPushToken[test-token]", platform: "android", device_name: "Pixel" } },
           as: :json
    end

    assert_response :success
    device = Mobile::Device.find_by!(expo_push_token: "ExponentPushToken[test-token]")
    assert_equal users(:david), device.user
    assert_equal "android", device.platform
    assert_equal "Pixel", device.device_name
    assert device.enabled?
  end

  test "create reassigns existing token to current user" do
    Mobile::Device.create!(
      user: users(:jason),
      expo_push_token: "ExponentPushToken[shared]",
      platform: "android",
      device_name: "Old device"
    )
    sign_in :david

    assert_no_difference -> { Mobile::Device.count } do
      post api_mobile_devices_url,
           params: { device: { expo_push_token: "ExponentPushToken[shared]", platform: "android", device_name: "New device" } },
           as: :json
    end

    assert_response :success
    device = Mobile::Device.find_by!(expo_push_token: "ExponentPushToken[shared]")
    assert_equal users(:david), device.user
    assert_equal "New device", device.device_name
  end
end
