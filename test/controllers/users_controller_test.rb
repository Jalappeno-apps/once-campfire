require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @join_code = accounts(:signal).join_code
  end

  test "show" do
    sign_in :david
    get user_url(users(:david))
    assert_response :ok
  end

  test "new" do
    get join_url(@join_code)
    assert_response :success
  end

  test "signed in user already in workspace is switched to that workspace" do
    sign_in :david

    get join_url(@join_code)
    assert_redirected_to root_url
  end

  test "signed in user not yet in workspace sees join confirmation" do
    other = Account.create!(name: "Sister Camp")

    sign_in :david
    get join_url(other.join_code)

    assert_response :success
    assert_select "strong", text: other.name
    assert_select "form[action=?]", join_path(other.join_code), count: 1
  end

  test "signed in user can join a new workspace from invite link" do
    other = Account.create!(name: "Sister Camp")

    sign_in :david
    assert_difference -> { users(:david).account_memberships.where(account: other).count }, 1 do
      post join_url(other.join_code)
    end

    assert_redirected_to root_url
    assert_equal other.id, Session.find_by(token: parsed_cookies.signed[:session_token]).account_id
  end

  test "new requires a join code" do
    get join_url("not")
    assert_response :not_found
  end

  test "create" do
    assert_difference -> { User.count }, 1 do
      post join_url(@join_code), params: { user: { name: "New Person", email_address: "new@37signals.com", password: "secret123456" } }
    end

    assert_redirected_to root_url

    user = User.last
    assert_equal user.id, Session.find_by(token: parsed_cookies.signed[:session_token]).user.id
    assert_equal user.rooms, Rooms::Open.all
  end

  test "create posts a welcome line in the first open channel when the workspace already has members" do
    first_open = Room.opens.where(account: accounts(:signal)).order(:created_at).first

    assert_difference -> { Message.where(room: first_open).count }, 1 do
      post join_url(@join_code), params: { user: { name: "Another Joiner", email_address: "another-joiner@example.com", password: "secret123456" } }
    end

    message = Message.where(room: first_open).order(:created_at).last
    assert_nil message.creator_id
    assert_includes message.plain_text_body, "Another Joiner"
    assert_includes message.plain_text_body, "just joined"
  end

  test "create records invited_by when join link includes invited_by" do
    assert_difference -> { User.count }, 1 do
      post join_url(@join_code, invited_by: users(:jason).id), params: { user: { name: "Invited Peer", email_address: "invited-peer@example.com", password: "secret123456" } }
    end

    membership = User.find_by!(email_address: "invited-peer@example.com").account_memberships.find_by!(account: accounts(:signal))
    assert_equal users(:jason).id, membership.invited_by_id
  end

  test "creating a new user with an existing email address will redirect to login screen" do
    assert_no_difference -> { User.count } do
      post join_url(@join_code), params: { user: { name: "Another David", email_address: users(:david).email_address, password: "secret123456" } }
    end

    assert_redirected_to new_session_url(email_address: users(:david).email_address)
  end
end
