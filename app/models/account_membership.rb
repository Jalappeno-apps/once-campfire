class AccountMembership < ApplicationRecord
  belongs_to :user
  belongs_to :account
  belongs_to :invited_by, class_name: "User", optional: true

  enum :role, %i[ member administrator ], default: :member

  validates :user_id, uniqueness: { scope: :account_id }

  after_create_commit :ensure_open_room_access
  after_create_commit :announce_new_member_in_open_room

  private
    def ensure_open_room_access
      return if user.bot?

      user.grant_open_room_memberships_for_account(account)
    end

    def announce_new_member_in_open_room
      return if user.bot?
      return unless other_human_members_already_in_workspace?

      room = account.rooms.opens.order(:created_at).first
      return unless room

      message = room.messages.create!(
        creator: nil,
        body: join_announcement_html
      )
      message.broadcast_create
    end

    def other_human_members_already_in_workspace?
      AccountMembership.where(account_id: account.id).where.not(id: id).exists?
    end

    def join_announcement_html
      safe = ERB::Util.html_escape(user.name)
      %(<div class="trix-content">#{safe} just joined the workspace — say hi!</div>)
    end
end
