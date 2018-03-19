class AddPreconditionToIssueToSpecialTest < ActiveRecord::Migration
  def change
    add_column :issue_to_special_tests, :precondition, :text
  end
end
