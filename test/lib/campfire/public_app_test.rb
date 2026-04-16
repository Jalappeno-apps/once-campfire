# frozen_string_literal: true

require "test_helper"

class Campfire::PublicAppTest < ActiveSupport::TestCase
  setup do
    @saved_public = ENV["PUBLIC_APP_URL"]
    @saved_app = ENV["APP_URL"]
  end

  teardown do
    restore_env "PUBLIC_APP_URL", @saved_public
    restore_env "APP_URL", @saved_app
  end

  test "origin is nil when unset" do
    ENV.delete("PUBLIC_APP_URL")
    ENV.delete("APP_URL")

    assert_nil Campfire::PublicApp.origin
  end

  test "origin parses PUBLIC_APP_URL" do
    ENV["PUBLIC_APP_URL"] = "https://chat.example.com"
    ENV.delete("APP_URL")

    assert_equal "https://chat.example.com", Campfire::PublicApp.origin
  end

  test "origin includes non-default https port" do
    ENV["PUBLIC_APP_URL"] = "https://chat.example.com:8443"

    assert_equal "https://chat.example.com:8443", Campfire::PublicApp.origin
  end

  test "origin prefers PUBLIC_APP_URL over APP_URL" do
    ENV["PUBLIC_APP_URL"] = "https://a.example.com"
    ENV["APP_URL"] = "https://b.example.com"

    assert_equal "https://a.example.com", Campfire::PublicApp.origin
  end

  private
    def restore_env(key, value)
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
end
