class CreateNotifications < ActiveRecord::Migration
  def change
    create_table :notifications do |t|
      t.string :category
      t.integer :based_id
      t.integer :status
      t.integer :from_user_id
      t.integer :to_user_id
      t.string :subject
      t.text :content
      t.boolean :is_read, default: false

      t.timestamps null: false
    end
  end
end
