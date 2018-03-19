class CreateNativeApplists < ActiveRecord::Migration
  def change
    create_table :native_applists do |t|
      t.string :name
      t.string :apk_name
      t.string :cn_name
      t.string :desktop_name
      t.text :description
      t.string :developer
      t.text :notes
      t.integer :author_id
      t.boolean :deleted, default: false
      t.datetime :deleted_at

      t.timestamps null: false
    end
  end
end
