class CreateTemplates < ActiveRecord::Migration
  def change
    create_table :templates do |t|
      t.integer :role_id
      t.integer :object_id
      t.integer :object_type
      t.integer :role_type
      t.integer :author_id

      t.timestamps null: false
    end

    add_index :templates, :role_id, :name => :templates_role_id
    add_index :templates, :object_id, :name => :templates_object_id
  end
end
