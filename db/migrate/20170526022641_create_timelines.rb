class CreateTimelines < ActiveRecord::Migration
  def change
    create_table :timelines do |t|
      t.integer :container_id
      t.string  :container_type
      t.string  :name
      t.string  :group_key
      t.integer :related_id
      t.integer :parent_id
      t.boolean :enable, default: true
      t.integer :author_id
      t.integer :time_display, default: 1

      t.timestamps null: false
    end
  end
end
