module MentionTestHelper
  def mention_attachment_for(name)
    user = users(name)
    attachment_body = ApplicationController.render partial: "users/mention", locals: { user: user }
    safe_content = attachment_body.gsub('"', "&quot;").gsub("%", "%25")
    "<action-text-attachment sgid=\"#{user.attachable_sgid}\" content-type=\"application/vnd.campfire.mention\" content=\"#{safe_content}\"></action-text-attachment>"
  end
end
