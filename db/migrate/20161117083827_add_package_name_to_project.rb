class AddPackageNameToProject < ActiveRecord::Migration
  def change
    add_column :projects, :package_name, :string
    add_column :projects, :dev_department, :string
  end
end
