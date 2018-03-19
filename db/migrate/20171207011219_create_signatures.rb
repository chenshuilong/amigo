class CreateSignatures < ActiveRecord::Migration
  def change
    create_table :signatures do |t|
      t.string   :name
      t.integer  :category
      t.string   :key_name
      t.string   :status
      t.text     :upload_url
      t.text     :download_url
      t.text     :infos
      t.text     :notes
      t.integer  :author_id
      t.datetime :due_at

      t.timestamps null: false
    end

    add_index :signatures, [:author_id]
  end
end
