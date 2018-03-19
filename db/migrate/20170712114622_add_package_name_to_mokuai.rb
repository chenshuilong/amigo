class AddPackageNameToMokuai < ActiveRecord::Migration
  def change
    add_column :mokuais, :package_name, :string
  end
end
