class AddGradleVersionToVersion < ActiveRecord::Migration
  def change
  	add_column :versions, :gradle_version, :string
  end
end
