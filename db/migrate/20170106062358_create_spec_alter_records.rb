class CreateSpecAlterRecords < ActiveRecord::Migration
  def change
    create_table :spec_alter_records do |t|
      t.references :spec, index: true
      t.references :user, index: true
      t.integer :record_type, default: 0 # add: 0, update: 1, delete: 2, locked: 3
      t.string :prop_key
      t.string :old_value
      t.string :value
      t.text :note

      t.timestamps null: false
    end
  end
end
