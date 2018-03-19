class CreateDefinitionSections < ActiveRecord::Migration
  def change
    create_table :definition_sections do |t|
      t.text    :name
      t.integer :parent_id
      t.integer :author_id
      t.boolean :display, default: true

      t.timestamps null: false
    end
  end
end
