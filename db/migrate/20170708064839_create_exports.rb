class CreateExports < ActiveRecord::Migration
  def change
    create_table :exports do |t|
      t.integer :category
      t.string  :name
      t.integer :status
      t.text    :sql
      t.text    :options
      t.string  :disk_file
      t.string  :format
      t.string  :file_size
      t.integer :lines
      t.integer :total_time
      t.integer :user_id
      t.boolean :deleted, default: false

      t.timestamps null: false
    end
  end
end
