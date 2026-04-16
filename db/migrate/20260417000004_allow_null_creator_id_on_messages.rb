class AllowNullCreatorIdOnMessages < ActiveRecord::Migration[8.2]
  def change
    change_column_null :messages, :creator_id, true
  end
end
