class AddMissingIndexesToDepts < ActiveRecord::Migration
  def change
    add_index :depts, :orgNo
  end
end
