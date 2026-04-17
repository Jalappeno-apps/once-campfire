require "test_helper"

class Calls::InvitesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "once.campfire.test"
    @previous_values = {
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

  test "redirects to destination for active invite token" do
    invite = Calls::Invite.create!(
      room: rooms(:designers),
      creator: users(:david),
      destination_url: "https://meet.daiwick.com/room-123?jwt=abc",
      expires_at: 30.minutes.from_now
    )

    get call_invite_url(token: invite.token)

    assert_redirected_to "https://meet.daiwick.com/room-123"
  end

  test "redirects via short /c route" do
    invite = Calls::Invite.create!(
      room: rooms(:designers),
      creator: users(:david),
      destination_url: "https://meet.daiwick.com/room-123?jwt=abc",
      expires_at: 30.minutes.from_now
    )

    get short_call_invite_url(token: invite.token)

    assert_redirected_to "https://meet.daiwick.com/room-123"
  end

  test "returns not found for unknown token" do
    get call_invite_url(token: "missingtoken")

    assert_response :not_found
  end

  test "returns not found for expired token" do
    invite = Calls::Invite.create!(
      room: rooms(:designers),
      creator: users(:david),
      destination_url: "https://meet.daiwick.com/room-123?jwt=abc",
      expires_at: 1.minute.ago
    )

    get call_invite_url(token: invite.token)

    assert_response :not_found
  end

  test "redirects when token contains trailing non-breaking space" do
    invite = Calls::Invite.create!(
      room: rooms(:designers),
      creator: users(:david),
      destination_url: "https://meet.daiwick.com/room-123?jwt=abc",
      expires_at: 30.minutes.from_now
    )

    get call_invite_url(token: "#{invite.token}\u00A0")

    assert_redirected_to "https://meet.daiwick.com/room-123"
  end

  test "removes only jwt query param from redirect destination" do
    invite = Calls::Invite.create!(
      room: rooms(:designers),
      creator: users(:david),
      destination_url: "https://meet.daiwick.com/room-123?foo=bar&jwt=abc&baz=1#config.prejoinConfig.enabled=false",
      expires_at: 30.minutes.from_now
    )

    get call_invite_url(token: invite.token)

    assert_redirected_to "https://meet.daiwick.com/room-123?foo=bar&baz=1#config.prejoinConfig.enabled=false"
  end

  test "returns not found for untrusted destination host" do
    invite = Calls::Invite.new(
      room: rooms(:designers),
      creator: users(:david),
      token: "evilhost1",
      destination_url: "https://example.com/room-123?jwt=abc",
      expires_at: 30.minutes.from_now
    )
    invite.save!(validate: false)

    get call_invite_url(token: invite.token)

    assert_response :not_found
  end

  test "adds member-specific jwt for authenticated room member" do
    ENV["JITSI_JWT_APP_ID"] = "campfire"
    ENV["JITSI_JWT_APP_SECRET"] = "secret"
    ENV["JITSI_JWT_AUDIENCE"] = "jitsi"
    ENV["JITSI_JWT_SUBJECT"] = "meet.daiwick.com"
    ENV["JITSI_JWT_TTL_SECONDS"] = "3600"
    sign_in(:david)

    invite = Calls::Invite.create!(
      room: rooms(:designers),
      creator: users(:david),
      destination_url: "https://meet.daiwick.com/room-123?jwt=creator-token",
      expires_at: 30.minutes.from_now
    )

    get call_invite_url(token: invite.token)

    redirected = URI.parse(response.redirect_url)
    jwt = CGI.parse(redirected.query.to_s)["jwt"].first
    payload, = JWT.decode(jwt, "secret", true, algorithm: "HS256")

    assert_equal "/room-123", redirected.path
    assert_equal users(:david).id.to_s, payload.dig("context", "user", "id")
  end

  test "does not add jwt for authenticated user outside room" do
    ENV["JITSI_JWT_APP_ID"] = "campfire"
    ENV["JITSI_JWT_APP_SECRET"] = "secret"
    outsider = User.create!(
      name: "Outside Member",
      email_address: "outside-member@example.com",
      password: "secret123456",
      password_confirmation: "secret123456"
    )
    AccountMembership.create!(user: outsider, account: rooms(:designers).account)
    sign_in(outsider)

    invite = Calls::Invite.create!(
      room: rooms(:designers),
      creator: users(:david),
      destination_url: "https://meet.daiwick.com/room-123?foo=bar&jwt=creator-token",
      expires_at: 30.minutes.from_now
    )

    get call_invite_url(token: invite.token)

    redirected = URI.parse(response.redirect_url)
    query = CGI.parse(redirected.query.to_s)

    assert_equal "/room-123", redirected.path
    assert_equal [ "bar" ], query["foo"]
    assert_not query.key?("jwt")
  end
end
