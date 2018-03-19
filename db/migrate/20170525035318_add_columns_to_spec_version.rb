class AddColumnsToSpecVersion < ActiveRecord::Migration
  def change
    add_column :spec_versions, :cn_name, :string
    add_column :spec_versions, :desktop_name, :string
    add_column :spec_versions, :description, :text
    add_column :spec_versions, :developer, :string
    add_column :spec_versions, :notes, :text
  end
end
