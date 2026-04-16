require "net/http"

module Mobile
  module Push
    class DeliveryClient
      class << self
        def deliver(payload:, devices:)
          messages = devices.pluck(:expo_push_token).uniq.map do |token|
            {
              to: token,
              sound: "default",
              title: payload[:title],
              body: payload[:body],
              data: { path: payload[:path] }
            }
          end

          if messages.empty?
            Rails.logger.info("Mobile push skipped: no eligible device tokens")
            return
          end

          response = Net::HTTP.start(endpoint.host, endpoint.port, use_ssl: endpoint.scheme == "https") do |http|
            request = Net::HTTP::Post.new(endpoint.request_uri, headers)
            request.body = messages.to_json
            http.request(request)
          end

          unless response.is_a?(Net::HTTPSuccess)
            Rails.logger.error("Mobile push send failed status=#{response.code} body=#{response.body}")
            return
          end

          log_ticket_errors(response)
        rescue StandardError => error
          Rails.logger.error("Mobile push send error=#{error.class} message=#{error.message}")
        end

        private
          def endpoint
            @endpoint ||= URI(ENV.fetch("MOBILE_PUSH_DELIVERY_URL", "https://exp.host/--/api/v2/push/send"))
          end

          def headers
            {
              "accept" => "application/json",
              "content-type" => "application/json"
            }
          end

          def log_ticket_errors(response)
            data = JSON.parse(response.body).fetch("data", [])
            Array(data).each do |ticket|
              next unless ticket["status"] == "error"
              details = ticket["details"].is_a?(Hash) ? ticket["details"].to_json : ticket["details"].to_s
              Rails.logger.error("Mobile push ticket error message=#{ticket["message"]} details=#{details}")
            end
          rescue JSON::ParserError
            Rails.logger.warn("Mobile push response was not valid JSON")
          end
      end
    end
  end
end
