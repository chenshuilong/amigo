class CreateAlterRecords < ActiveRecord::Migration
  def change
    create_table :alter_records do |t|
      t.integer :alter_for_id
      t.string :alter_for_type
      t.integer :user_id
      t.text :notes

      t.timestamps null: false
    end
  end
end
