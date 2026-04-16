class Accounts::WorkspacesController < ApplicationController
  before_action :ensure_workspace_administrator

  def new
    @account = Account.new(name: "New workspace")
  end

  def create
    account = Account.create!(workspace_params)
    AccountMembership.create!(user: Current.user, account: account, role: :administrator)
    room = Rooms::Open.create_for({ name: "All Talk", account: account }, users: Current.user)
    Current.session.update!(account_id: account.id)
    redirect_to room_url(room)
  end

  private
    def workspace_params
      params.require(:account).permit(:name)
    end
end
