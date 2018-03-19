class AddAppVersionTypeToProject < ActiveRecord::Migration
  def change
    add_column :projects, :app_version_type, :text
  end
end
