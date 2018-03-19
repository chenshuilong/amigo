class AddColumnsToProject < ActiveRecord::Migration
  def change
    add_column :projects, :sub_production_type, :integer
    add_column :projects, :developer, :text
    add_column :projects, :note, :text
  end
end
