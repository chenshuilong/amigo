class CreateDefinitionAlterRecords < ActiveRecord::Migration
  def change
    create_table :definition_alter_records do |t|
      t.integer    :definition_id
      t.integer    :user_id
      t.integer    :record_type
      t.string     :prop_key
      t.text       :old_value
      t.text       :value

      t.timestamps null: false
    end
  end
end
