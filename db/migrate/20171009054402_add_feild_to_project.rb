class AddFeildToProject < ActiveRecord::Migration
  def change
    add_column :projects, :plan_status, :string
    add_column :projects, :next_step, :string

    add_index :plans, [:project_id, :name]
  end
end
