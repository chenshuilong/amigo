class CreateNewFeatures < ActiveRecord::Migration
  def change
    create_table :new_features do |t|
      t.integer :category
      t.string :description

      t.timestamps null: false
    end
  end
end
