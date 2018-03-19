class AddColumnToProject < ActiveRecord::Migration
  def change
    add_column :projects, :plan_locked, :boolean, default: false
  end
end
