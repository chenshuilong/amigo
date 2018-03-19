class CreateVersionReleaseSdks < ActiveRecord::Migration
  def change
    create_table :version_release_sdks do |t|
      t.integer :version_id
      t.integer :status
      t.text :result
      t.text :maven_result
      t.text :release_project_ids
      t.integer :author_id
      t.text :note

      t.timestamps null: false
    end
  end
end
