class Accounts::UsersController < ApplicationController
  before_action :ensure_workspace_administrator, :set_user, only: %i[ update destroy ]

  def index
    set_page_and_extract_portion_from Current.account.users.active.ordered.without_bots, per_page: 500
  end

  def update
    membership = @user.account_memberships.find_by!(account: Current.account)
    role = params.require(:user)[:role].presence_in(%w[ member administrator ]) || "member"
    membership.update!(role: role)
    redirect_to edit_account_url
  end

  def destroy
    @user.deactivate
    redirect_to edit_account_url
  end

  private
    def set_user
      @user = Current.account.users.active.find(params[:user_id] || params[:id])
    end
end
