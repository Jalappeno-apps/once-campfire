class Accounts::SwitchesController < ApplicationController
  def create
    account = Current.user.accounts.find(params[:account_id])
    Current.session.update!(account_id: account.id)
    redirect_to root_url, status: :see_other
  rescue ActiveRecord::RecordNotFound
    head :forbidden
  end
end
