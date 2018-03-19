class CreateVersionPermissions < ActiveRecord::Migration
  def change
    create_table :version_permissions do |t|
      t.string :name
      t.text :meaning
      t.integer :author_id

      t.timestamps null: false
    end

    add_column :version_permissions, :deleted, :boolean, :default => false
    add_column :version_permissions, :deleted_by_id, :integer 

    VersionPermission.create(name:"remove_notes")
  end
end
