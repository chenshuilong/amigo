class CreateApkBases < ActiveRecord::Migration
  def change
    create_table :apk_bases do |t|
      t.string  :name
      t.string  :cn_name
      t.string  :en_name
      t.text    :cn_description
      t.text    :en_description
      t.string  :desktop_name
      t.boolean :desktop_icon
      t.string  :developer
      t.string  :package_name
      t.integer :category_id
      t.boolean :removable
      t.integer :os_category
      t.integer :app_category
      t.integer :author_id, null:false
      
      t.timestamps null: false
    end
  end
end
