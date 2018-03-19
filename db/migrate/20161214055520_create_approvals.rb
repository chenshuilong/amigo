class CreateApprovals < ActiveRecord::Migration
  def change
    create_table :approvals do |t|
      t.string :type
      t.string :object_type
      t.integer :object_id
      t.references :user, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
