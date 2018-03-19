class CreateQandaTable < ActiveRecord::Migration
  def change
    create_table :qandas do |t|
      t.string :subject
      t.text :content
      t.string :tag
      t.integer :total_read, default: 0

      t.timestamps null: false
    end
  end
end
