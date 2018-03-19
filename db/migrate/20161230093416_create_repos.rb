class CreateRepos < ActiveRecord::Migration
  def change
    create_table :repos do |t|
      t.string :name, limit: 255, null: false
      t.string :description, limit: 255
      t.integer :type, limit: 1, null: false
      t.integer :is_spec_versions, limit: 1, null: false
      t.string :url, limit: 255, null: false
      t.integer :url_type, limit: 1, null: false
      t.integer :author_id, null:false
      t.timestamps null: false
    end
  end
end
