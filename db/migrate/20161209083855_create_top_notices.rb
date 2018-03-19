class CreateTopNotices < ActiveRecord::Migration
  def change
    create_table :top_notices do |t|
      t.integer :receiver_type
      t.string :receivers
      t.string :message
      t.date :expired
      t.string :uniq_key
      t.references :user, index: true
      t.timestamps null: false
    end
  end
end
