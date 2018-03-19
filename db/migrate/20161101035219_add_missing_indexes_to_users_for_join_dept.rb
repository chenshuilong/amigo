class AddMissingIndexesToUsersForJoinDept < ActiveRecord::Migration
  def change
    add_index :users, :orgNo
  end
end
