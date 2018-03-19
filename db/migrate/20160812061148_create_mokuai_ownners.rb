class CreateMokuaiOwnners < ActiveRecord::Migration
  def change
    create_table :mokuai_ownners do |t|
      t.references :project, index: true, foreign_key: true
      t.references :mokuai, index: true, foreign_key: true
      t.integer :ownner

      t.timestamps null: false
    end
  end
end
