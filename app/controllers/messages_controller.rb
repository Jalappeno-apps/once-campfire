class MessagesController < ApplicationController
  include ActiveStorage::SetCurrent, RoomScoped

  before_action :set_room, except: :create
  before_action :set_message, only: %i[ show edit update destroy ]
  before_action :ensure_can_administer, only: %i[ edit update destroy ]

  layout false, only: :index

  def index
    @messages = find_paged_messages

    if @messages.any?
      fresh_when @messages
    else
      head :no_content
    end
  end

  def create
    set_room
    @message = @room.messages.create_with_attachment!(normalized_message_params)

    @message.broadcast_create
    deliver_webhooks_to_bots
  rescue ActiveRecord::RecordNotFound
    render action: :room_not_found
  end

  def show
  end

  def edit
  end

  def update
    @message.update!(message_params)

    @message.broadcast_replace_to @room, :messages, target: [ @message, :presentation ], partial: "messages/presentation", attributes: { maintain_scroll: true }
    redirect_to room_message_url(@room, @message)
  end

  def destroy
    @message.destroy
    @message.broadcast_remove
  end

  private
    def normalized_message_params
      attrs = message_params.to_h.symbolize_keys
      attrs[:body] = meet_invite_message(attrs[:body]) if meet_command?(attrs[:body])
      attrs
    end

    def set_message
      @message = @room.messages.find(params[:id])
    end

    def ensure_can_administer
      head :forbidden unless Current.user.can_administer?(@message)
    end


    def find_paged_messages
      case
      when params[:before].present?
        @room.messages.with_creator.page_before(@room.messages.find(params[:before]))
      when params[:after].present?
        @room.messages.with_creator.page_after(@room.messages.find(params[:after]))
      else
        @room.messages.with_creator.last_page
      end
    end


    def message_params
      params.require(:message).permit(:body, :attachment, :client_message_id)
    end

    def meet_command?(raw_body)
      text = ActionText::Content.new(raw_body.to_s).to_plain_text
      text = text.unicode_normalize.gsub(/\p{Space}+/, " ").strip
      text.match?(%r{\A/meet(?:\s+.*)?\z}i)
    end

    def meet_invite_message(raw_body)
      invite_prefix = "Join call: #{Calls::MeetLinkBuilder.call(room: @room, creator: Current.user)}"
      raw_body.to_s.sub(%r{/meet}i, invite_prefix)
    end


    def deliver_webhooks_to_bots
      bots_eligible_for_webhook.excluding(@message.creator).each { |bot| bot.deliver_webhook_later(@message) }
    end

    def bots_eligible_for_webhook
      @room.direct? ? @room.users.active_bots : @message.mentionees.active_bots
    end
end
