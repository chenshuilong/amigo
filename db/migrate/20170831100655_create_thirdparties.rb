class CreateThirdparties < ActiveRecord::Migration
  def change
    create_table :thirdparties do |t|
      t.integer :spec_id
      t.integer :author_id
      t.integer :status, default: 0
      t.text :version_ids
      t.text :note

      t.timestamps null: false
    end
  end
end
