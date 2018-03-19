class ChangeReposFields < ActiveRecord::Migration
  def change
    remove_column :repos, :name, :string, limit: 255
    remove_column :repos, :is_spec_versions, :integer, limit: 1
    change_column :repos, :description, :text
    rename_column :repos, :type, :category
  end
end