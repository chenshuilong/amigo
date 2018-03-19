class CreateDemands < ActiveRecord::Migration
  def change
    create_table :demands do |t|
      t.integer :category_id
      t.integer :sub_category_id
      t.integer :status
      t.text    :description
      t.text    :method
      t.string  :related_ids
      t.text    :related_notes
      t.integer :author_id
      t.date    :feedback_at

      t.timestamps null: false
    end
  end
end
