class Accounts::Bots::KeysController < ApplicationController
  before_action :ensure_workspace_administrator

  def update
    User.active_bots.joins(:account_memberships).where(account_memberships: { account_id: Current.account.id }).find(params[:bot_id]).reset_bot_key
    redirect_to account_bots_url
  end
end
