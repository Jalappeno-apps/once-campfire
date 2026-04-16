require "test_helper"

class FirstRunTest < ActiveSupport::TestCase
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

  test "creating makes first user an administrator" do
    user = create_first_run_user
    assert user.administrator?
  end

  test "first user has access to first room" do
    user = create_first_run_user
    assert user.rooms.one?
  end

  test "first room is an open room" do
    create_first_run_user
    assert Room.first.open?
  end

  private
    def create_first_run_user
      FirstRun.create!({ name: "User", email_address: "user@example.com", password: "secret123456" })
    end
end
