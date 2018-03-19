class CreateDefinitionSectionsCustomFields < ActiveRecord::Migration
  def change
    create_table :definition_sections_custom_fields do |t|
      t.integer :definition_section_id
      t.integer :custom_field_id
      t.integer :sort
    end
  end
end
