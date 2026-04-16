module SignInBranding
  extend ActiveSupport::Concern

  SESSION_KEY = :branding_account_id

  private
    def assign_sign_in_branding_from_params
      if request.get? && action_name == "new"
        acc = resolve_branding_account_from_params
        if acc
          session[SESSION_KEY] = acc.id
        else
          session.delete(SESSION_KEY)
        end
      elsif request.post? && action_name == "create"
        acc = resolve_branding_account_from_params
        session[SESSION_KEY] = acc.id if acc
      end
      sync_sign_in_account_from_session
    end

    def resolve_branding_account_from_params
      if (jc = params[:join_code].presence)
        Account.find_by(join_code: jc)
      elsif (aid = params[:account_id].presence)
        Account.find_by(id: aid)
      end
    end

    def sync_sign_in_account_from_session
      Current.sign_in_account =
        session[SESSION_KEY] && Account.find_by(id: session[SESSION_KEY])
    end

    # Logo is requested in a separate HTTP request without invite_account; session carries workspace id.
    def prepare_sign_in_branding_for_logo_request
      return if Current.user
      sync_sign_in_account_from_session
    end
end
