class ChangeUmpirageApproverTypeInIssue < ActiveRecord::Migration
  def change
    change_column :issues, :umpirage_approver_id, :text
  end
end
