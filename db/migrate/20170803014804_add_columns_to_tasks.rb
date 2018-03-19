class AddColumnsToTasks < ActiveRecord::Migration
  def change
    add_column :tasks, :actual_start_date, :datetime, :after => :due_date
    add_column :tasks, :actual_due_date, :datetime, :after => :actual_start_date
    add_column :tasks, :notes, :text, :after => :description
    add_column :spec_versions, :deleted_at, :datetime, :after => :deleted
  end
end
