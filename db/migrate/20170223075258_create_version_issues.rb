class CreateVersionIssues < ActiveRecord::Migration
  def change
    create_table :version_issues do |t|
      t.references :version, index: true
      t.integer :issue_type
      t.integer :issue_id
      t.string  :status
      t.string  :subject
      t.string  :assigned_to

      t.timestamps null: false
    end
  end
end
