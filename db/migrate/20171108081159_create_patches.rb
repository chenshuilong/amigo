class CreatePatches < ActiveRecord::Migration
  def change
    create_table :patches do |t|
      t.string  :patch_no
      t.integer :patch_type
      t.integer :status
      t.text    :init_command
      t.text    :notes
      t.integer :author_id
      t.date    :due_at
      t.date    :actual_due_at

      t.timestamps null: false
    end

    create_table :libraries do |t|
      t.integer :container_id
      t.string  :container_type
      t.string  :name
      t.string  :path
      t.string :status
      t.string  :change_type
      t.integer :user_id
      t.text    :files

      t.timestamps null: false
    end

    create_table :library_duties do |t|
      t.string  :name
      t.string  :path
      t.integer :user_id
      t.text    :notes

      t.timestamps null: false
    end

    add_index :libraries, [:container_id, :container_type, :user_id]
    add_index :patches, :author_id
    add_index :library_duties, :user_id
  end
end
