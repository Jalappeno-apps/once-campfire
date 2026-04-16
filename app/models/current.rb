class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user, :request
  attribute :invite_account
  attribute :sign_in_account

  delegate :host, :protocol, to: :request, prefix: true, allow_nil: true

  def session=(value)
    super(value)

    if value.present?
      self.user = session.user
    end
  end

  def account
    return invite_account if invite_account
    return resolve_account_from_session if user
    sign_in_account
  end

  def account_membership
    return unless user && account
    user.account_memberships.find_by(account: account)
  end

  private
    def resolve_account_from_session
      return unless session && user
      aid = session.account_id
      return unless aid
      acc = Account.find_by(id: aid)
      return unless acc && user.account_memberships.exists?(account_id: acc.id)
      acc
    end
end
