module Authorization
  private
    def ensure_can_administer
      head :forbidden unless Current.user.can_administer?
    end

    def ensure_workspace_administrator
      head :forbidden unless Current.user.workspace_administrator?(Current.account)
    end
end
