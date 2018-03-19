class AddColumnsToPatch < ActiveRecord::Migration
  def change
    add_column :patches, :proprietary_tag, :string, :after => :author_id
    add_column :patches, :object_ids, :text, :after => :proprietary_tag
    add_column :patches, :object_names, :text, :after => :object_ids
    add_column :patches, :reason, :text, :after => :object_names
    add_column :libraries, :uniq_key, :integer, :after => :files

    change_column :patches, :status, :string

    create_table :library_files do |t|
      t.integer  :library_id
      t.string   :name
      t.string   :status
      t.string   :conflict_type
      t.string   :email
      t.integer  :user_id

      t.timestamps null: false
    end

    create_table :patch_versions do |t|
      t.integer :patch_id
      t.string  :category
      t.string  :name
      t.integer :object_id
      t.string  :object_name
      t.text    :version_url
      t.text    :version_log
      t.string  :status
      t.string  :result
      t.string  :operate_type
      t.integer :software_manager_id
      t.integer :test_manager_id
      t.integer :user_id
      t.string  :role_type
      t.datetime  :due_at

      t.timestamps null: false
    end

    drop_table :library_duties

    add_index :library_files, [:library_id, :user_id]
    add_index :patch_versions, [:patch_id]
  end
end
