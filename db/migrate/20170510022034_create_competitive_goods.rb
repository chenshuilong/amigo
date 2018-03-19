class CreateCompetitiveGoods < ActiveRecord::Migration
  def change
    create_table :competitive_goods do |t|
      t.references :user
      t.text :name

      t.timestamps null: false
    end
  end
end
