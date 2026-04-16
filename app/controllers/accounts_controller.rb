class AccountsController < ApplicationController
  before_action :ensure_workspace_administrator, only: :update
  before_action :set_account

  def edit
    users = account_users.ordered.without_bots
    @administrators, @members = users.partition { |u| u.workspace_administrator?(Current.account) }
    set_page_and_extract_portion_from users, per_page: 500
  end

  def update
    @account.update!(account_params)
    redirect_to edit_account_url, notice: "✓"
  end

  private
    def set_account
      @account = Current.account
    end

    def account_params
      params.require(:account).permit(:name, :logo, settings: {})
    end

    def account_users
      base = Current.account.users
      rel = User.where(id: base.select(:id))
      if Current.user.workspace_administrator?(Current.account)
        rel.where(status: [ :active, :banned ])
      else
        rel.active
      end
    end
end
