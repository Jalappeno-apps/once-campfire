class Accounts::JoinCodesController < ApplicationController
  before_action :ensure_workspace_administrator

  def create
    Current.account.reset_join_code
    redirect_to edit_account_url
  end
end
