class AddFieldToSpec < ActiveRecord::Migration
  def change
    add_column :specs, :is_colleted, :boolean, default: 0 # default value is 0 --uncolleted
  end
end
