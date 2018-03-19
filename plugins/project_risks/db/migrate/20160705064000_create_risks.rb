class CreateRisks < ActiveRecord::Migration
  def change
    create_table :risks do |t|
      t.references :project, index: true, foreign_key: true
      t.string :department
      t.string :category
      t.text :description
      t.references :user, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
