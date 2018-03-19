class CreateDefinitionCustomValues < ActiveRecord::Migration
  def change
    create_table :definition_custom_values do |t|
      t.integer  :definition_id
      t.integer  :definition_section_id
      t.integer  :custom_field_id
      t.text     :value
      t.boolean  :display, default: true
      t.integer  :sort

      t.timestamps null: false
    end
  end
end
