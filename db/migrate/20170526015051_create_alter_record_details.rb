class CreateAlterRecordDetails < ActiveRecord::Migration
  def change
    create_table :alter_record_details do |t|
      t.integer :alter_record_id
      t.string :property
      t.string :prop_key
      t.text :old_value
      t.text :value

      t.timestamps null: false
    end
  end
end
