# frozen_string_literal: true

module Campfire
  # Optional public origin for building absolute URLs when +Host+ from the reverse proxy is wrong
  # (e.g. placeholder hostname). Set +PUBLIC_APP_URL+ or +APP_URL+ to the URL users use in the browser,
  # e.g. +https://campfire.example.com+ (no path).
  module PublicApp
    module_function

    def origin
      raw = ENV["PUBLIC_APP_URL"].presence || ENV["APP_URL"].presence
      return nil if raw.blank?

      uri = URI.parse(raw.strip)
      return nil unless uri.scheme.in?(%w[http https]) && uri.host.present?

      base = +"#{uri.scheme}://#{uri.host}"
      base << ":#{uri.port}" if uri.port && uri.port != uri.default_port
      base.freeze
    rescue URI::InvalidURIError
      nil
    end
  end
end
