class CreateMokuais < ActiveRecord::Migration
  def change
    create_table :mokuais do |t|
      t.integer :category
      t.string :reason
      t.string :name
      t.text :description

      t.timestamps null: false
    end
  end
end
