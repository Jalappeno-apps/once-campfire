require "test_helper"

class FirstRunsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActiveRecord::Base.connection.disable_referential_integrity do
      ActiveRecord::Base.connection.tables.each do |table|
        next if table.in?(%w[ schema_migrations ar_internal_metadata ])
        next if table.start_with?("sqlite_")
        next if table == "message_search_index"

        ActiveRecord::Base.connection.execute("DELETE FROM #{ActiveRecord::Base.connection.quote_table_name(table)}")
      end
    end
  end

  test "new is permitted when no other users exit" do
    get first_run_url
    assert_response :success
  end

  test "new is not permitted when account exist" do
    Account.create!(name: "Chat")

    get first_run_url
    assert_redirected_to root_url
  end

  test "create" do
    assert_difference -> { Room.count }, 1 do
      assert_difference -> { User.count }, 1 do
        post first_run_url, params: { account: { name: "37signals" }, user: { name: "New Person", email_address: "new@37signals.com", password: "secret123456" } }
      end
    end

    assert_redirected_to root_url

    assert parsed_cookies.signed[:session_token]
  end

  test "create is not vulnerable to race conditions" do
    num_attackers = 5
    url = first_run_url
    barrier = Concurrent::CyclicBarrier.new(num_attackers)

    num_attackers.times.map do |i|
      Thread.new do
        session = ActionDispatch::Integration::Session.new(Rails.application)
        barrier.wait  # All threads wait here, then fire simultaneously

        session.post url, params: {
          user: {
            name: "Attacker#{i}",
            email_address: "attacker#{i}@example.com",
            password: "password123"
          }
        }
      end
    end.each(&:join)

    assert_equal 1, Account.count, "Race condition allowed #{Account.count} accounts to be created!"
    assert_equal 1, User.where(role: :administrator).count, "Race condition allowed multiple admin users!"
  end
end
