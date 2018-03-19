class AddColumnToVersionAndTask < ActiveRecord::Migration
  def change
    add_column :tasks, :is_read, :boolean, default: false
    add_column :versions, :finger_print, :string
  end
end
