module EnsureWorkspaceSession
  extend ActiveSupport::Concern

  included do
    before_action :ensure_workspace_session_matches_membership
  end

  private
    def ensure_workspace_session_matches_membership
      return unless Current.user && Current.session
      return if Current.invite_account

      aid = Current.session.account_id
      return if aid && Current.user.account_memberships.exists?(account_id: aid)

      new_aid = Current.user.account_memberships.order(:created_at).pick(:account_id)
      if new_aid
        Current.session.update!(account_id: new_aid)
      else
        terminate_current_session
        redirect_to root_url
      end
    end
end
