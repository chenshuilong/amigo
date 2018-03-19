class CreateVersionPublishes < ActiveRecord::Migration
  def change
    create_table :version_publishes do |t|
      t.integer :version_id
      t.text :content
      t.string :content_md5
      t.boolean :published
      t.integer :author_id

      t.timestamps null: false
    end

    add_column :version_publishes, :notes, :text
    add_column :version_publishes, :spec_id, :integer
    add_column :version_publishes, :published_on, :datetime
    add_column :version_publishes, :publisher_id, :integer

    change_column :version_publishes, :published, :boolean, :default => false
  end
end
