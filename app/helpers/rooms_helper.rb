module RoomsHelper
  ONLINE_WINDOW = 5.minutes
  FILE_KIND_ALL = "all"
  FILE_KINDS = [ "documents", "media", "other" ].freeze

  def link_to_room(room, **attributes, &)
    link_to room_path(room), **attributes, data: {
      rooms_list_target: "room",
      room_id: room.id,
      badge_dot_target: "unread",
      sorted_list_target: "item",
      action: "click->rooms-list#read"
    }.merge(attributes.delete(:data) || {}), &
  end

  def link_to_edit_room(room, &)
    link_to \
      [ :edit, @room ],
      class: "btn",
      style: "view-transition-name: edit-room-#{@room.id}",
      data: { room_id: @room.id },
      &
  end

  def link_back_to_last_room_visited
    if last_room = last_room_visited
      link_back_to room_path(last_room)
    else
      link_back_to root_path
    end
  end

  def button_to_delete_room(room, url: nil)
    button_to url || room_url(room), method: :delete, class: "btn btn--negative max-width", aria: { label: "Delete #{room.name}" },
        data: { turbo_confirm: "Are you sure you want to delete this room and all messages in it? This can’t be undone." } do
      image_tag("trash.svg", aria: { hidden: "true" }, size: 20) +
      tag.span(room_display_name(room), class: "overflow-ellipsis")
    end
  end

  def button_to_jump_to_newest_message
    tag.button \
        class: "message-area__return-to-latest btn",
        data: { action: "messages#returnToLatest", messages_target: "latest" },
        hidden: true do
      image_tag("arrow-down.svg", aria: { hidden: "true" }, size: 20) +
      tag.span("Jump to newest message", class: "for-screen-reader")
    end
  end

  def submit_room_button_tag
    button_tag class: "btn btn--reversed txt-large center", type: "submit" do
      image_tag("check.svg", aria: { hidden: "true" }, size: 20) +
      tag.span("Save", class: "for-screen-reader")
    end
  end

  def composer_form_tag(room, &)
    form_with model: Message.new, url: room_messages_path(room),
      id: "composer", class: "margin-block flex-item-grow contain", data: composer_data_options(room), &
  end

  def room_display_name(room, for_user: Current.user)
    @room_display_name_cache ||= {}
    cache_key = [ room.id, for_user&.id ]
    return @room_display_name_cache[cache_key] if @room_display_name_cache.key?(cache_key)

    @room_display_name_cache[cache_key] =
      if room.direct?
        names =
          if room.association(:users).loaded?
            room.users.reject { |u| for_user && u.id == for_user.id }.map(&:name)
          else
            room.users.without(for_user).pluck(:name)
          end
        names.to_sentence.presence || for_user&.name
      else
        room.name
      end
  end

  def room_info_path(room)
    if room.direct?
      peers = room.direct_peers_excluding(Current.user)
      return user_path(peers.first) if peers.one?

      return edit_rooms_direct_path(room)
    end

    if room.open?
      edit_rooms_open_path(room)
    elsif room.closed?
      edit_rooms_closed_path(room)
    else
      room_path(room)
    end
  end

  def user_online?(user)
    return false unless user

    user_last_active_at(user)&.>=(ONLINE_WINDOW.ago) && !user.availability_invisible?
  end

  def user_last_active_at(user)
    return unless user

    account_presence_last_active_at[user.id]
  end

  def user_presence_label(user)
    return "Offline" unless user

    case user_presence_state(user)
    when :online
      "Online"
    when :away
      "Away"
    when :do_not_disturb
      "Do not disturb"
    else
      last_active_at = user_last_active_at(user)
      last_active_at ? "Last active #{time_ago_in_words(last_active_at)} ago" : "Offline"
    end
  end

  def user_presence_state(user)
    return :offline unless user_online?(user)
    return :do_not_disturb if user.availability_do_not_disturb?
    return :away if user.availability_away?

    :online
  end

  def user_presence_badge_class(user)
    case user_presence_state(user)
    when :online
      "profile-presence-badge--online"
    when :away
      "profile-presence-badge--away"
    when :do_not_disturb
      "profile-presence-badge--dnd"
    else
      "profile-presence-badge--offline"
    end
  end

  def user_status_text(user)
    user.active_custom_status || user_presence_label(user)
  end

  def room_direct_presence_title(room)
    peers = room.direct_peers_excluding(Current.user).reject(&:bot?)
    return "" if peers.empty?

    online_count = peers.count { |peer| user_online?(peer) }
    return "#{online_count} online" if online_count.positive?

    last_seen = peers.map { |peer| user_last_active_at(peer) }.compact.max
    return "Offline" unless last_seen

    "Last active #{time_ago_in_words(last_seen)} ago"
  end

  def file_kind_for_attachment(attachment)
    content_type = attachment&.content_type.to_s
    filename = attachment&.filename.to_s.downcase

    return "media" if content_type.start_with?("image/", "video/", "audio/")
    return "documents" if content_type.start_with?("text/")
    return "documents" if content_type.start_with?("application/pdf", "application/msword", "application/vnd", "application/rtf", "application/json", "application/xml")
    return "documents" if filename.match?(/\.(txt|pdf|doc|docx|xls|xlsx|csv|ppt|pptx|md|json|xml|rtf)\z/)

    "other"
  end

  def file_kind_label(kind)
    case kind
    when "documents" then "Documents"
    when "media" then "Media"
    when "other" then "Other files"
    else "All files"
    end
  end

  private
    def account_presence_last_active_at
      return {} unless Current.account

      @account_presence_last_active_at ||= Session.where(account_id: Current.account.id).group(:user_id).maximum(:last_active_at)
    end

    def composer_data_options(room)
      {
        controller: "composer drop-target",
        action: composer_data_actions,
        composer_messages_outlet: "#message-area",
        composer_toolbar_class: "composer--rich-text", composer_room_id_value: room.id
      }
    end

    def composer_data_actions
      drag_and_drop_actions = "drop-target:drop@window->composer#dropFiles"

      trix_attachment_actions =
        "trix-file-accept->composer#preventAttachment refresh-room:online@window->composer#online"

      remaining_actions =
        "typing-notifications#stop paste->composer#pasteFiles turbo:submit-end->composer#submitEnd refresh-room:offline@window->composer#offline"

      [ drop_target_actions, drag_and_drop_actions, trix_attachment_actions, remaining_actions ].join(" ")
    end
end
