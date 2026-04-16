# frozen_string_literal: true

require "test_helper"

class MessagesHelperTest < ActionView::TestCase
  tests MessagesHelper

  setup do
    @saved_public = ENV["PUBLIC_APP_URL"]
    @saved_app = ENV["APP_URL"]
  end

  teardown do
    restore_env "PUBLIC_APP_URL", @saved_public
    restore_env "APP_URL", @saved_app
  end

  test "absolute_call_link_for joins relative path with request base when env unset" do
    ENV.delete("PUBLIC_APP_URL")
    ENV.delete("APP_URL")

    expected = URI.join("#{request.base_url.chomp("/")}/", "/c/abc123").to_s
    assert_equal expected, absolute_call_link_for("/c/abc123")
  end

  test "absolute_call_link_for prefers PUBLIC_APP_URL for relative paths" do
    ENV["PUBLIC_APP_URL"] = "https://campfire.example.org"
    ENV.delete("APP_URL")

    assert_equal "https://campfire.example.org/c/abc123", absolute_call_link_for("/c/abc123")
  end

  test "absolute_call_link_for falls back to APP_URL when PUBLIC_APP_URL unset" do
    ENV.delete("PUBLIC_APP_URL")
    ENV["APP_URL"] = "https://app.example.org"

    assert_equal "https://app.example.org/c/xyz", absolute_call_link_for("/c/xyz")
  end

  test "absolute_call_link_for leaves absolute URLs unchanged" do
    ENV["PUBLIC_APP_URL"] = "https://ignored.example.org"

    assert_equal "https://meet.example.com/room", absolute_call_link_for("https://meet.example.com/room")
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
