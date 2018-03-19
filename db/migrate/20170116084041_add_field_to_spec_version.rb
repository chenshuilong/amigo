class AddFieldToSpecVersion < ActiveRecord::Migration
  def change
    add_column :spec_versions, :created_at, :datetime
    add_column :spec_versions, :updated_at, :datetime
    add_column :spec_versions, :mark, :text
  end
end
