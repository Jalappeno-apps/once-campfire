class Room::MessagePusher
  attr_reader :room, :message

  def initialize(room:, message:)
    @room, @message = room, message
  end

  def push
    build_payload.tap do |payload|
      if targeted_call_invite?(payload)
        push_to_targeted_call_users(payload)
        push_to_targeted_mobile_call_users(payload)
      else
        push_to_users_involved_in_everything(payload)
        push_to_users_involved_in_mentions(payload)
        push_to_mobile_users_involved_in_everything(payload)
        push_to_mobile_users_involved_in_mentions(payload)
      end
    end
  end

  private
    def build_payload
      base_payload = if room.direct?
        build_direct_payload
      else
        build_shared_payload
      end

      with_call_metadata(base_payload)
    end

    def build_direct_payload
      {
        title: message.creator&.name || room.name,
        body: message.plain_text_body,
        path: Rails.application.routes.url_helpers.room_at_message_path(room, message)
      }
    end

    def build_shared_payload
      {
        title: room.name,
        body: message.creator ? "#{message.creator.name}: #{message.plain_text_body}" : message.plain_text_body,
        path: Rails.application.routes.url_helpers.room_at_message_path(room, message)
      }
    end

    def with_call_metadata(payload)
      call_link = Calls::InviteLinkExtractor.call(message.plain_text_body)
      return payload unless call_link
      return payload if scheduled_call_message?
      call_url = Calls::InviteUrlResolver.call(call_link)
      return payload unless call_url

      payload.merge(
        type: "incoming_call",
        title: room.direct? ? "#{message.creator&.name || "Someone"} is calling" : "Incoming call in #{room.name}",
        body: room.direct? ? "Tap to join the call" : "#{message.creator&.name || "Someone"} started a call",
        call_url: call_url,
        caller_name: message.creator&.name || "Someone",
        room_name: room.name
      )
    end

    def scheduled_call_message?
      message.plain_text_body.start_with?("Scheduled call (")
    end

    def push_to_users_involved_in_everything(payload)
      enqueue_payload_for_delivery payload, push_subscriptions_for_users_involved_in_everything
    end

    def push_to_users_involved_in_mentions(payload)
      enqueue_payload_for_delivery payload, push_subscriptions_for_mentionable_users(message.mentionees)
    end

    def push_to_mobile_users_involved_in_everything(payload)
      enqueue_mobile_payload_for_delivery payload, mobile_devices_for_users_involved_in_everything
    end

    def push_to_mobile_users_involved_in_mentions(payload)
      enqueue_mobile_payload_for_delivery payload, mobile_devices_for_mentionable_users(message.mentionees)
    end

    def push_to_targeted_call_users(payload)
      enqueue_payload_for_delivery payload, push_subscriptions_for_targeted_call_users
    end

    def push_to_targeted_mobile_call_users(payload)
      enqueue_mobile_payload_for_delivery payload, mobile_devices_for_targeted_call_users
    end

    def push_subscriptions_for_users_involved_in_everything
      relevant_subscriptions.merge(Membership.involved_in_everything)
    end

    def push_subscriptions_for_mentionable_users(mentionees)
      relevant_subscriptions.merge(Membership.involved_in_mentions).where(user_id: mentionees.ids)
    end

    def mobile_devices_for_users_involved_in_everything
      relevant_mobile_devices.merge(Membership.involved_in_everything)
    end

    def mobile_devices_for_mentionable_users(mentionees)
      relevant_mobile_devices.merge(Membership.involved_in_mentions).where(user_id: mentionees.ids)
    end

    def push_subscriptions_for_targeted_call_users
      relevant_subscriptions
    end

    def mobile_devices_for_targeted_call_users
      relevant_mobile_devices
    end

    def targeted_call_invite?(payload)
      payload[:type] == "incoming_call"
    end

    def relevant_subscriptions
      memberships_scope = Membership.visible.disconnected.where(room: room)
      memberships_scope = memberships_scope.where.not(user_id: message.creator_id) if message.creator_id

      Push::Subscription
        .joins(user: :memberships)
        .merge(memberships_scope)
    end

    def relevant_mobile_devices
      memberships_scope = Membership.visible.where(room: room)
      memberships_scope = memberships_scope.where.not(user_id: message.creator_id) if message.creator_id

      Mobile::Device
        .enabled
        .joins(user: :memberships)
        .merge(memberships_scope)
    end

    def enqueue_payload_for_delivery(payload, subscriptions)
      Rails.configuration.x.web_push_pool.queue(payload, subscriptions)
    end

    def enqueue_mobile_payload_for_delivery(payload, devices)
      Mobile::Push::DeliveryClient.deliver(payload: payload.merge(message_id: message.id), devices: devices)
    end
end
