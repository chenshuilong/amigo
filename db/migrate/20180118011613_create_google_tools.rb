class CreateGoogleTools < ActiveRecord::Migration
  def change
    create_table :google_tools do |t|
      t.integer  :category
      t.string   :android_version
      t.string   :tool_version
      t.text     :tool_url
      t.text     :notes
      t.datetime :closed_at
      t.integer  :author_id

      t.timestamps null: false
    end

    create_table :tools do |t|
      t.integer  :category
      t.string   :name
      t.text     :description
      t.text     :notes
      t.integer  :provider_id
      t.integer  :author_id

      t.timestamps null: false
    end

    add_index :google_tools, [:author_id]
    add_index :tools, [:provider_id, :author_id]

    add_column :attachments, :extra_type, :string
  end
end
