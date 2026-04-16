class UsersController < ApplicationController
  require_unauthenticated_access only: %i[ new create ]
  skip_before_action :redirect_signed_in_user_to_root, only: %i[ new create ]

  before_action :set_user, only: :show
  before_action :verify_join_code, only: %i[ new create ]

  def new
    if signed_in?
      invite = Current.invite_account
      if Current.user.account_memberships.exists?(account_id: invite.id)
        switch_session_to_workspace(invite)
        return
      end
      render :join_workspace
    else
      @user = User.new
    end
  end

  def create
    if signed_in?
      invite = Current.invite_account
      invited_by_id = session.delete(:join_invited_by_id)
      Current.user.account_memberships.find_or_create_by!(account: invite) do |membership|
        membership.role = :member
        membership.invited_by_id = invited_by_id
      end
      Current.session.update!(account_id: invite.id)
      redirect_to root_url
    else
      create_user_from_invite
    end
  end

  def show
  end

  private
    def set_user
      @user = User.find(params[:id])
    end

    def verify_join_code
      acc = Account.find_by(join_code: params[:join_code])
      unless acc
        head :not_found
        return
      end

      Current.invite_account = acc
      session[SignInBranding::SESSION_KEY] = acc.id
      assign_invited_by_session(acc)
    end

    def assign_invited_by_session(account)
      uid = params[:invited_by].presence
      if uid && account.users.active.exists?(id: uid)
        session[:join_invited_by_id] = uid.to_i
      else
        session.delete(:join_invited_by_id)
      end
    end

    def user_params
      params.require(:user).permit(:name, :avatar, :email_address, :password)
    end

    def switch_session_to_workspace(account)
      Current.session.update!(account_id: account.id)
      redirect_to root_url
    end

    def create_user_from_invite
      @user = User.new(user_params)
      @user.provisioning_account = Current.invite_account
      @user.save!
      AccountMembership.create!(
        user: @user,
        account: Current.invite_account,
        role: :member,
        invited_by_id: session.delete(:join_invited_by_id)
      )
      start_new_session_for @user, account: Current.invite_account
      redirect_to root_url
    rescue ActiveRecord::RecordNotUnique
      redirect_to new_session_url(email_address: user_params[:email_address])
    end
end
