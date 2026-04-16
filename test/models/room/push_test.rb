require "test_helper"

class Room::PushTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "deliver new message to other room users with push subscriptions" do
    task_count = Push::Subscription.count - users(:david).push_subscriptions.count
    perform_enqueued_jobs only: Room::PushMessageJob do
      WebPush.expects(:payload_send).times(task_count)
      rooms(:hq).messages.create! body: "This is from earth", client_message_id: "earth", creator: users(:david)
    end
    wait_for_web_push_delivery_pool_tasks(task_count)
  end

  test "notifies subscribed users" do
    perform_enqueued_jobs only: Room::PushMessageJob do
      WebPush.expects(:payload_send).times(2)
      rooms(:designers).messages.create! body: "This is from earth", client_message_id: "earth", creator: users(:david)
    end
    wait_for_web_push_delivery_pool_tasks(2)

    perform_enqueued_jobs only: Room::PushMessageJob do
      WebPush.expects(:payload_send).times(3)
      rooms(:designers).messages.create! body: "Hey #{mention_attachment_for(:kevin)}", client_message_id: "earth", creator: users(:david)
    end
    wait_for_web_push_delivery_pool_tasks(5)
  end

  test "does not notify for connected rooms" do
    memberships(:kevin_designers).connected

    perform_enqueued_jobs only: Room::PushMessageJob do
      WebPush.expects(:payload_send).times(2)
      rooms(:designers).messages.create! body: "Hey @kevin", client_message_id: "earth", creator: users(:david)
    end
    wait_for_web_push_delivery_pool_tasks(2)
  end

  test "does not notify for invisible rooms" do
    memberships(:kevin_designers).update! involvement: "invisible"

    perform_enqueued_jobs only: Room::PushMessageJob do
      WebPush.expects(:payload_send).times(2)
      rooms(:designers).messages.create! body: "Hey @kevin", client_message_id: "earth", creator: users(:david)
    end
    wait_for_web_push_delivery_pool_tasks(2)
  end

  test "destroys invalid subscriptions" do
    memberships(:kevin_designers).update! involvement: "invisible"

    assert_difference -> { Push::Subscription.count }, -2 do
      perform_enqueued_jobs only: Room::PushMessageJob do
        WebPush.expects(:payload_send).times(2).raises(WebPush::ExpiredSubscription.new(Struct.new(:body).new, "example.com"))
        rooms(:designers).messages.create! body: "Hey @kevin", client_message_id: "earth", creator: users(:david)
      end
      wait_for_web_push_delivery_pool_tasks(2)
      wait_for_invalidation_pool_tasks(2)
    end
  end

  test "delivers native mobile notifications through expo client" do
    Mobile::Device.create!(
      user: users(:jason),
      expo_push_token: "ExponentPushToken[jason-device]",
      platform: "android",
      device_name: "Pixel"
    )

    perform_enqueued_jobs only: Room::PushMessageJob do
      Mobile::Push::DeliveryClient.expects(:deliver).at_least_once
      rooms(:designers).messages.create! body: "This should notify mobile", client_message_id: "native-mobile", creator: users(:david)
    end
  end

  private
    def wait_for_web_push_delivery_pool_tasks(count)
      wait_for_pool_tasks(Rails.configuration.x.web_push_pool.delivery_pool, count)
    end

    def wait_for_invalidation_pool_tasks(count)
      wait_for_pool_tasks(Rails.configuration.x.web_push_pool.invalidation_pool, count)
    end

    def wait_for_pool_tasks(pool, expected_completed_tasks)
      timeout_seconds = 10.0
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout_seconds

      loop do
        completed_tasks = pool.completed_task_count
        return if completed_tasks >= expected_completed_tasks

        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          raise "Timeout waiting for pool tasks to complete (expected #{expected_completed_tasks}, got #{completed_tasks})"
        end

        sleep 0.1
      end
    end
end
