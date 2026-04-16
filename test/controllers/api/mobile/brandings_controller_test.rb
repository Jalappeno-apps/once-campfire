require "test_helper"

class Api::Mobile::BrandingsControllerTest < ActionDispatch::IntegrationTest
  test "show requires authentication" do
    get api_mobile_branding_url, as: :json

    assert_response :unauthorized
  end

  test "show returns account branding" do
    sign_in :david

    get api_mobile_branding_url, as: :json

    assert_response :success
    assert_equal accounts(:signal).name, response.parsed_body["account_name"]
    assert_includes response.parsed_body["logo_url"], "/account/logo"
  end
end
