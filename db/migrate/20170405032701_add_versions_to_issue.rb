class AddVersionsToIssue < ActiveRecord::Migration
  def change
    add_column :issues, :app_version_id, :integer # 应用版本
    add_column :issues, :integration_version_id, :integer # 集成版本
  end
end
