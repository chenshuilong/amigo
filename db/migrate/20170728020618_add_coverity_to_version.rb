class AddCoverityToVersion < ActiveRecord::Migration
  def change
    add_column :versions, :coverity, :boolean
  end
end
