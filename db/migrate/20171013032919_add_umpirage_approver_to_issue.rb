class AddUmpirageApproverToIssue < ActiveRecord::Migration
  def change
    add_column :issues, :umpirage_approver_id, :integer
  end
end
