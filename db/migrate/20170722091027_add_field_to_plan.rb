class AddFieldToPlan < ActiveRecord::Migration
  def change
    add_column :plans, :assigned_to_note, :text
    add_column :plans, :checker_note, :text
    add_column :plans, :author_note, :text

    add_column :issue_to_approve_merges, :repo_request_ids, :text
  end
end
