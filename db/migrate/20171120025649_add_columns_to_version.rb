class AddColumnsToVersion < ActiveRecord::Migration
  def change
    add_column :versions, :special_app_versions, :text
    add_column :versions, :version_yaml, :text
  end
end
