class CreateConditionHistories < ActiveRecord::Migration
  def change
    create_table :condition_histories do |t|
      t.integer :from_id
      t.references :user, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
