class AddFeildToPlan < ActiveRecord::Migration
  def change
    add_column :plans, :position, :integer
  end
end
