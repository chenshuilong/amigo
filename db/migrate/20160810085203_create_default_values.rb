class CreateDefaultValues < ActiveRecord::Migration
  def change
    create_table :default_values do |t|
      t.string :category
      t.references :user, index: true, foreign_key: true
      t.string :name
      t.text :json

      t.timestamps null: false
    end
  end
end
