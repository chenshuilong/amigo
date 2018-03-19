class AddGroupKeyToVersion < ActiveRecord::Migration
  def change
    add_column :versions, :group_key, :string
  end
end
