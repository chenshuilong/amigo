class CreateIssueGerrits < ActiveRecord::Migration
  def change
    create_table :issue_gerrits do |t|
      t.references :issue, index: true, foreign_key: true
      t.references :user, index: true, foreign_key: true
      t.string :message
      t.string :link
      t.string :repository
      t.string :branch

      t.timestamps null: false
    end
  end
end
