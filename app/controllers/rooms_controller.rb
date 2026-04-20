class RoomsController < ApplicationController
  FILES_PAGE_SIZE = 80
  DOCUMENT_EXTENSIONS = %w[txt pdf doc docx xls xlsx csv ppt pptx md json xml rtf].freeze

  before_action :set_room, only: %i[ show destroy ]
  before_action :ensure_can_administer, only: %i[ destroy ]
  before_action :remember_last_room_visited, only: :show

  def index
    redirect_to room_url(Current.user.rooms_in_account(Current.account).last)
  end

  def show
    @active_room_tab = params[:tab].presence_in(%w[ messages files ]) || "messages"
    @file_query = params[:q].to_s.strip
    @file_kind = params[:kind].presence_in([ RoomsHelper::FILE_KIND_ALL, *RoomsHelper::FILE_KINDS ]) || RoomsHelper::FILE_KIND_ALL
    @messages = find_messages
    @file_cursor = file_cursor_from_params
    @file_messages, @file_has_more = find_file_messages if @active_room_tab == "files"
  end

  def destroy
    @room.destroy

    broadcast_remove_room
    redirect_to root_url
  end

  private
    def set_room
      if room = Current.user.rooms_in_account(Current.account).find_by(id: params[:room_id] || params[:id])
        @room = room
      else
        redirect_to root_url, alert: "Room not found or inaccessible"
      end
    end

    def ensure_can_administer
      head :forbidden unless Current.user.can_administer?(@room)
    end

    def ensure_permission_to_create_rooms
      if Current.account.settings.restrict_room_creation_to_administrators? && !Current.user.workspace_administrator?(Current.account)
        head :forbidden
      end
    end

    def find_messages
      messages = @room.messages.with_creator.with_attachment_details.with_boosts
      messages = messages.where.associated(:attachment_attachment) if @active_room_tab == "files"

      if show_first_message = messages.find_by(id: params[:message_id])
        @messages = messages.page_around(show_first_message)
      else
        @messages = messages.last_page
      end
    end

    def find_file_messages
      scope = @room.messages
        .with_creator
        .with_attachment_details
        .where.associated(:attachment_attachment)
        .joins(attachment_attachment: :blob)

      if @file_query.present?
        query = "%#{ActiveRecord::Base.sanitize_sql_like(@file_query.downcase)}%"
        scope = scope.where("LOWER(active_storage_blobs.filename) LIKE ?", query)
      end

      if @file_kind != RoomsHelper::FILE_KIND_ALL
        scope = scope_for_file_kind(scope)
      end

      if @file_cursor
        scope = scope.where(
          "messages.created_at < :created_at OR (messages.created_at = :created_at AND messages.id < :id)",
          created_at: @file_cursor[:created_at], id: @file_cursor[:id]
        )
      end

      messages = scope
        .order(created_at: :desc, id: :desc)
        .limit(FILES_PAGE_SIZE + 1)
        .to_a

      has_more = messages.length > FILES_PAGE_SIZE
      [ messages.first(FILES_PAGE_SIZE), has_more ]
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

    def file_cursor_from_params
      return unless params[:before_created_at].present? && params[:before_id].present?

      created_at = Time.zone.parse(params[:before_created_at].to_s)
      id = params[:before_id].to_i
      return unless created_at && id.positive?

      { created_at: created_at, id: id }
    rescue ArgumentError
      nil
    end

    def scope_for_file_kind(scope)
      case @file_kind
      when "media"
        scope.where(*media_condition)
      when "documents"
        scope.where(*documents_condition)
      when "other"
        scope.where.not(*media_condition).where.not(*documents_condition)
      else
        scope
      end
    end

    def media_condition
      [ "active_storage_blobs.content_type LIKE ? OR active_storage_blobs.content_type LIKE ? OR active_storage_blobs.content_type LIKE ?", "image/%", "video/%", "audio/%" ]
    end

    def documents_condition
      filename_clauses = DOCUMENT_EXTENSIONS.map { "LOWER(active_storage_blobs.filename) LIKE ?" }
      filename_values = DOCUMENT_EXTENSIONS.map { |ext| "%.#{ext}" }
      [ [
          "active_storage_blobs.content_type LIKE ?",
          "active_storage_blobs.content_type LIKE ?",
          "active_storage_blobs.content_type LIKE ?",
          "active_storage_blobs.content_type LIKE ?",
          "active_storage_blobs.content_type LIKE ?",
          "active_storage_blobs.content_type LIKE ?",
          "(#{filename_clauses.join(' OR ')})"
        ].join(" OR "),
        "text/%",
        "application/pdf%",
        "application/msword%",
        "application/vnd%",
        "application/rtf%",
        "application/json%",
        *filename_values
      ]
    end

    def room_params
      params.require(:room).permit(:name)
    end

    def broadcast_remove_room
      broadcast_remove_to [ @room.account, :rooms ], target: [ @room, :list ]
    end
end
