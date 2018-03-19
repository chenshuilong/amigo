class AddFieldToSpecAlterRecord < ActiveRecord::Migration
  def change
    add_column :spec_alter_records, :app_id, :integer
  end
end
