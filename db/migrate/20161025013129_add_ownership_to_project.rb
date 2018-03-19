class AddOwnershipToProject < ActiveRecord::Migration
  def change
    add_column :projects, :ownership, :integer, default: 1
  end
end
