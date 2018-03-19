class CreateDocumentAttachments < ActiveRecord::Migration
  def change
    create_table :document_attachments do |t|
      t.integer :document_id
      t.string :category_id
      t.string :attachment_id

      t.timestamps null: false
    end
  end
end
