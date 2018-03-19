class CreateTasks < ActiveRecord::Migration
  def change
    create_table :tasks do |t|
      t.integer :container_id
      t.string :container_type
      t.string :name
      t.integer :assigned_to_id
      t.integer :author_id
      t.integer :status, default: 1
      t.text :description
      t.datetime :start_date
      t.datetime :due_date

      t.timestamps null: false
    end
  end
end
