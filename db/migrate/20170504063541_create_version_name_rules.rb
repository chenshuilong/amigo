class CreateVersionNameRules < ActiveRecord::Migration
  def change
    create_table :version_name_rules do |t|
      t.string :name
      t.text :description
      t.string :range
      t.integer :author_id
      t.timestamps null: false
    end
  end
end
