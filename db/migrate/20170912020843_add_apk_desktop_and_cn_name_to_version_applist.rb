class AddApkDesktopAndCnNameToVersionApplist < ActiveRecord::Migration
  def change
    create_table :project_apks do |t|
      t.integer :project_id
      t.integer :apk_base_id
      t.integer :author_id
      t.boolean :deleted, default: false
      t.integer :deleted_by_id
      t.datetime :deleted_at

      t.timestamps null: false
    end
    add_index :project_apks, [:project_id, :apk_base_id], :unique => true, :name => :project_apks_ids

    add_column :version_applists, :apk_cn_name, :string
    add_column :version_applists, :apk_desktop, :boolean
  end
end
