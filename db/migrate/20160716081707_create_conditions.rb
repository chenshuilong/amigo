class CreateConditions < ActiveRecord::Migration
  def change
    create_table :conditions do |t|
      t.integer  :category, default: 1
      t.string  :name
      t.boolean  :is_folder, default: false
      t.integer  :folder_id
      t.references  :user, index: true
      t.text  :condition
      t.text :column_order
      t.integer  :project_id
      t.text  :json

      t.timestamps null: false
    end
  end
end
