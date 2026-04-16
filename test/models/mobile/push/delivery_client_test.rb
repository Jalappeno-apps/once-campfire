require "test_helper"

class Mobile::Push::DeliveryClientTest < ActiveSupport::TestCase
  setup do
    @previous_endpoint = ENV["MOBILE_PUSH_DELIVERY_URL"]
    reset_endpoint_cache
  end

  teardown do
    ENV["MOBILE_PUSH_DELIVERY_URL"] = @previous_endpoint
    reset_endpoint_cache
  end

  test "normalizes host-only endpoint and uses expo default path" do
    ENV["MOBILE_PUSH_DELIVERY_URL"] = "exp.host"

    device = Mobile::Device.create!(
      user: users(:jason),
      expo_push_token: "ExponentPushToken[test-device]",
      platform: "android",
      device_name: "Pixel"
    )

    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.stubs(:body).returns({ data: [] }.to_json)

    http = mock("net-http")
    http.expects(:request).with do |request|
      request.is_a?(Net::HTTP::Post) &&
        request.path == "/--/api/v2/push/send" &&
        request["content-type"] == "application/json"
    end.returns(response)

    Net::HTTP.expects(:start).with("exp.host", 443, use_ssl: true).yields(http)

    Mobile::Push::DeliveryClient.deliver(
      payload: { title: "Campfire", body: "Message", path: "/rooms/1" },
      devices: Mobile::Device.where(id: device.id)
    )
  end

  test "falls back to expo default endpoint when env is blank" do
    ENV["MOBILE_PUSH_DELIVERY_URL"] = ""

    device = Mobile::Device.create!(
      user: users(:jason),
      expo_push_token: "ExponentPushToken[test-device-blank-endpoint]",
      platform: "android",
      device_name: "Pixel"
    )

    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.stubs(:body).returns({ data: [] }.to_json)

    http = mock("net-http")
    http.expects(:request).with do |request|
      request.is_a?(Net::HTTP::Post) && request.path == "/--/api/v2/push/send"
    end.returns(response)

    Net::HTTP.expects(:start).with("exp.host", 443, use_ssl: true).yields(http)

    Mobile::Push::DeliveryClient.deliver(
      payload: { title: "Campfire", body: "Message", path: "/rooms/1" },
      devices: Mobile::Device.where(id: device.id)
    )
  end

  test "sends high-priority metadata for incoming calls" do
    ENV["MOBILE_PUSH_DELIVERY_URL"] = ""

    device = Mobile::Device.create!(
      user: users(:jason),
      expo_push_token: "ExponentPushToken[test-device-incoming-call]",
      platform: "android",
      device_name: "Pixel"
    )

    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.stubs(:body).returns({ data: [] }.to_json)

    http = mock("net-http")
    http.expects(:request).with do |request|
      body = JSON.parse(request.body).first
      body["priority"] == "high" &&
        body["channelId"] == "calls" &&
        body["categoryId"] == "incoming_call" &&
        body["categoryIdentifier"] == "incoming_call" &&
        body["data"]["type"] == "incoming_call" &&
        body["data"]["call_url"] == "https://meet.jit.si/call-room"
    end.returns(response)

    Net::HTTP.expects(:start).with("exp.host", 443, use_ssl: true).yields(http)

    Mobile::Push::DeliveryClient.deliver(
      payload: {
        title: "Incoming call",
        body: "Ritwick is calling",
        path: "/rooms/1",
        type: "incoming_call",
        call_url: "https://meet.jit.si/call-room",
        caller_name: "Ritwick",
        room_name: "General"
      },
      devices: Mobile::Device.where(id: device.id)
    )
  end

  private
    def reset_endpoint_cache
      singleton_class = Mobile::Push::DeliveryClient.singleton_class
      singleton_class.remove_instance_variable(:@endpoint) if singleton_class.instance_variable_defined?(:@endpoint)
    end
end
