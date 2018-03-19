class AddSomeDatesToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :adaptive_date, :text
    add_column :projects, :full_featured_date, :text
    add_column :projects, :version_complete_date, :text
    add_column :projects, :ota_month, :string
    add_column :projects, :platform_version_export_date, :text
    add_column :projects, :storage_version_export_date, :text
    add_column :projects, :storage_test_complete_date, :text
    add_column :projects, :storage_complete_date, :text
    add_column :projects, :initiate_date, :text
    add_column :projects, :release_date, :text
  end
end
