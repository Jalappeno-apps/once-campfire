module MessagesHelper
  def message_area_tag(room, &)
    tag.div id: "message-area", class: "message-area", contents: true, data: {
      controller: "messages presence drop-target",
      action: [ messages_actions, drop_target_actions, presence_actions ].join(" "),
      messages_first_of_day_class: "message--first-of-day",
      messages_formatted_class: "message--formatted",
      messages_me_class: "message--me",
      messages_mentioned_class: "message--mentioned",
      messages_threaded_class: "message--threaded",
      messages_page_url_value: room_messages_url(room)
    }, &
  end

  def messages_tag(room, &)
    tag.div id: dom_id(room, :messages), class: "messages", data: {
      controller: "maintain-scroll refresh-room",
      action: [ maintain_scroll_actions, refresh_room_actions ].join(" "),
      messages_target: "messages",
      refresh_room_loaded_at_value: room.updated_at.to_fs(:epoch),
      refresh_room_url_value: room_refresh_url(room)
    }, &
  end

  def message_tag(message, &)
    message_timestamp_milliseconds = message.created_at.to_fs(:epoch)

    data = {
      user_id: message.creator_id,
      message_id: message.id,
      message_timestamp: message_timestamp_milliseconds,
      message_updated_at: message.updated_at.to_fs(:epoch),
      sort_value: message_timestamp_milliseconds,
      messages_target: "message",
      search_results_target: "message",
      refresh_room_target: "message",
      reply_composer_outlet: "#composer"
    }
    data[:controller] = "reply" if message.creator_id

    tag.div id: dom_id(message),
      class: [
        "message",
        ("message--emoji" if message.plain_text_body.all_emoji?),
        ("message--system" if message.system?)
      ].compact.join(" "),
      data: data, &
  rescue Exception => e
    Sentry.capture_exception(e, extra: { message: message })
    Rails.logger.error "Exception while rendering message #{message.class.name}##{message.id}, failed with: #{e.class} `#{e.message}`"

    render "messages/unrenderable"
  end

  def message_timestamp(message, **attributes)
    local_datetime_tag message.created_at, **attributes
  end

  def message_presentation(message)
    case message.content_type
    when "attachment"
      message_attachment_presentation(message)
    when "sound"
      message_sound_presentation(message)
    else
      text_message_presentation(message)
    end
  rescue Exception => e
    Sentry.capture_exception(e, extra: { message: message })
    Rails.logger.error "Exception while generating message representation for #{message.class.name}##{message.id}, failed with: #{e.class} `#{e.message}`"

    ""
  end

  private
    def messages_actions
      "turbo:before-stream-render@document->messages#beforeStreamRender keydown.up@document->messages#editMyLastMessage"
    end

    def maintain_scroll_actions
      "turbo:before-stream-render@document->maintain-scroll#beforeStreamRender"
    end

    def refresh_room_actions
      "visibilitychange@document->refresh-room#visibilityChanged online@window->refresh-room#online"
    end

    def presence_actions
      "visibilitychange@document->presence#visibilityChanged"
    end

    def message_attachment_presentation(message)
      Messages::AttachmentPresentation.new(message, context: self).render
    end

    def message_sound_presentation(message)
      sound = message.sound

      tag.div class: "sound", data: { controller: "sound", action: "messages:play->sound#play", sound_url_value: asset_path(sound.asset_path) } do
        play_button + (sound.image ? sound_image_tag(sound.image) : sound.text)
      end
    end

    def play_button
      tag.button "🔊", class: "btn btn--plain", data: { action: "sound#play" }
    end

    def sound_image_tag(image)
      image_tag image.asset_path, width: image.width, height: image.height, class: "align--middle"
    end

    def message_author_title(author)
      [ author.name, author.bio ].compact_blank.join(" – ")
    end

    def text_message_presentation(message)
      content = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
      linked_content = auto_link h(content), html: { target: "_blank" }
      call_link = trusted_call_link_from(content)
      return linked_content unless call_link

      safe_join([ linked_content, call_invite_card(message, call_link, scheduled_at: scheduled_call_time_from(content)) ])
    end

    def trusted_call_link_from(content)
      Calls::InviteLinkExtractor.call(content)
    end

    def trusted_call_hosts
      Calls::Configuration.trusted_hosts
    end

    def call_invite_card(message, call_link, scheduled_at: nil)
      tag.div class: "message__call-invite" do
        items = [
          tag.div("Video call", class: "message__call-invite-title"),
          tag.div(call_link, class: "message__call-invite-link"),
          tag.div(class: "message__call-invite-actions") do
            action_buttons = [ link_to("Join call", call_link, class: "btn btn--reversed message__call-invite-btn") ]
            if scheduled_at
              action_buttons << link_to(
                "Add to calendar",
                google_calendar_url(call_link, scheduled_at, calendar_invite_emails_for(message)),
                class: "btn btn--plain message__call-invite-calendar",
                target: "_blank",
                rel: "noopener"
              )
            end
            safe_join(action_buttons)
          end
        ]

        safe_join(items)
      end
    end

    def scheduled_call_time_from(content)
      text = ActionText::Content.new(content.to_s).to_plain_text.unicode_normalize
      match = text.match(/Scheduled call \((?<scheduled_at>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2})\):/i)
      return nil unless match

      Time.zone.strptime(match[:scheduled_at], "%Y-%m-%d %H:%M")
    rescue ArgumentError
      nil
    end

    def google_calendar_url(call_link, scheduled_at, attendees)
      ends_at = scheduled_at + 1.hour
      absolute_call_link = absolute_call_link_for(call_link)
      params = {
        action: "TEMPLATE",
        text: "Campfire call",
        details: "Join call: #{absolute_call_link}",
        location: absolute_call_link,
        # Keep the user-selected local wall time (no UTC coercion) so Google
        # Calendar opens with the exact hour typed in `/meet at`.
        dates: "#{scheduled_at.strftime("%Y%m%dT%H%M%S")}/#{ends_at.strftime("%Y%m%dT%H%M%S")}"
      }
      params[:add] = attendees.join(",") if attendees.any?

      "https://calendar.google.com/calendar/render?#{params.to_query}"
    end

    def calendar_invite_emails_for(message)
      mentionee_emails = message.mentionees.map(&:email_address).compact_blank
      body_emails = extract_emails_from(message.plain_text_body)
      (mentionee_emails + body_emails).map(&:downcase).uniq
    end

    def extract_emails_from(text)
      text.to_s.scan(/[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}/i)
    end

    def absolute_call_link_for(call_link)
      uri = URI.parse(call_link.to_s)
      return uri.to_s if uri.host.present?

      base = Campfire::PublicApp.origin.presence || request.base_url
      URI.join("#{base.chomp("/")}/", call_link.to_s.sub(/\A\/+/, "/")).to_s
    rescue URI::InvalidURIError
      call_link.to_s
    end
end
