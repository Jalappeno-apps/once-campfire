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
    @recent_direct_rooms = recent_direct_rooms_for(@user)
    @profile_stats = profile_stats_for(@user)
    @primary_direct_room = primary_direct_room_for(@user)
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

    def recent_direct_rooms_for(user)
      return [] unless Current.user && user && Current.account

      Current.user.rooms_in_account(Current.account).directs.includes(:users).select { |room|
        room.user_ids.include?(user.id) && room.id != params[:room_id].to_i
      }.sort_by(&:updated_at).reverse.first(5)
    end

    def primary_direct_room_for(user)
      return unless Current.user && user && Current.account

      Current.user.rooms_in_account(Current.account).directs.includes(:users).select { |room|
        room.user_ids.include?(user.id)
      }.max_by(&:updated_at)
    end

    def profile_stats_for(user)
      return {} unless Current.user && user && Current.account

      rooms_in_account = Current.user.rooms_in_account(Current.account).includes(:users)
      shared_rooms = rooms_in_account.select { |room| room.user_ids.include?(user.id) }
      shared_direct_rooms = shared_rooms.select(&:direct?)

      {
        shared_rooms_count: shared_rooms.size,
        shared_channels_count: shared_rooms.count { |room| !room.direct? },
        first_direct_started_at: shared_direct_rooms.map(&:created_at).compact.min,
        last_direct_activity_at: shared_direct_rooms.map(&:updated_at).compact.max
      }
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
