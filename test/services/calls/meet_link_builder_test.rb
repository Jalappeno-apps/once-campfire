require "test_helper"

class Calls::MeetLinkBuilderTest < ActiveSupport::TestCase
  setup do
    @previous_values = {
      "MEET_BASE_URL" => ENV["MEET_BASE_URL"],
      "JITSI_JWT_APP_ID" => ENV["JITSI_JWT_APP_ID"],
      "JITSI_JWT_APP_SECRET" => ENV["JITSI_JWT_APP_SECRET"],
      "JITSI_JWT_AUDIENCE" => ENV["JITSI_JWT_AUDIENCE"],
      "JITSI_JWT_SUBJECT" => ENV["JITSI_JWT_SUBJECT"],
      "JITSI_JWT_TTL_SECONDS" => ENV["JITSI_JWT_TTL_SECONDS"]
    }
  end

  teardown do
    @previous_values.each { |key, value| ENV[key] = value }
  end

  test "builds a default meet room link with room id" do
    ENV["MEET_BASE_URL"] = nil
    ENV["JITSI_JWT_APP_ID"] = nil
    ENV["JITSI_JWT_APP_SECRET"] = nil

    url = Calls::MeetLinkBuilder.call(room: rooms(:watercooler))
    expected_host = URI.parse(Calls::Configuration::DEFAULT_MEET_BASE_URL).host

    assert_match %r{\Ahttps://#{Regexp.escape(expected_host)}/\S+#config\.prejoinConfig\.enabled=false&config\.visitors\.enabled=false\z}, url
    assert_includes url, "-#{rooms(:watercooler).id}-"
  end

  test "includes jwt query param when jwt env is configured" do
    ENV["JITSI_JWT_APP_ID"] = "campfire"
    ENV["JITSI_JWT_APP_SECRET"] = "secret"
    ENV["JITSI_JWT_AUDIENCE"] = "jitsi"
    ENV["JITSI_JWT_SUBJECT"] = "meet.daiwick.com"
    ENV["JITSI_JWT_TTL_SECONDS"] = "3600"

    url = Calls::MeetLinkBuilder.call(room: rooms(:watercooler), creator: users(:david))
    jwt = CGI.parse(URI.parse(url).query.to_s)["jwt"].first
    payload, header = JWT.decode(jwt, "secret", true, algorithm: "HS256")

    assert_equal "campfire", payload["iss"]
    assert_equal "jitsi", payload["aud"]
    assert_equal "meet.daiwick.com", payload["sub"]
    assert_equal users(:david).name, payload.dig("context", "user", "name")
    assert_equal "JWT", header["typ"]
  end
end
