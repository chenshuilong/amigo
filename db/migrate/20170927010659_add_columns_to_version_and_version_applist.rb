class AddColumnsToVersionAndVersionApplist < ActiveRecord::Migration
  def change
    add_column :versions, :system_space, :text
    add_column :version_applists, :apk_size_comparable, :boolean
  end
end
