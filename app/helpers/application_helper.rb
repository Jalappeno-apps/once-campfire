module ApplicationHelper
  def workspace_initials(name)
    parts = name.to_s.split(/\s+/).map { |w| w[0] }.compact_blank
    raw = parts.first(2).join.presence || name.to_s[0..1].to_s
    raw.present? ? raw.upcase : "?"
  end

  def workspace_administrator?
    Current.user&.workspace_administrator?(Current.account)
  end

  def workspace_accounts_for_nav
    @workspace_accounts_for_nav ||= Current.user&.accounts&.order(:name)&.with_attached_logo&.load || []
  end

  def page_title_tag
    tag.title @page_title || "Campfire"
  end

  def current_user_meta_tags
    unless Current.user.nil?
      safe_join [
        tag(:meta, name: "current-user-id", content: Current.user.id),
        tag(:meta, name: "current-user-name", content: Current.user.name)
      ]
    end
  end

  def custom_styles_tag
    if custom_styles = Current.account&.custom_styles
      tag.style(custom_styles.to_s.html_safe, data: { turbo_track: "reload" })
    end
  end

  def body_classes
    [ @body_class, admin_body_class, account_logo_body_class ].compact.join(" ")
  end

  def link_back
    back_url = request.referrer
    back_url = root_path if back_url.nil? || back_url == request.url
    link_back_to back_url
  end

  def link_back_to(destination)
    link_to destination, class: "btn" do
      image_tag("arrow-left.svg", aria: { hidden: "true" }, size: 20) +
      tag.span("Go Back", class: "for-screen-reader")
    end
  end

  private
    def admin_body_class
      "admin" if Current.user&.can_administer?
    end

    def account_logo_body_class
      "account-has-logo" if Current.account&.logo&.attached?
    end
end
