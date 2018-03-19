class CreateViewRecords < ActiveRecord::Migration
  def change
    create_table :view_records do |t|
      t.integer :container_id
      t.string  :container_type
      t.integer :user_id

      t.timestamps null: false
    end

    add_index :view_records, [:container_id, :container_type]
    add_index :view_records, :user_id
  end
end
