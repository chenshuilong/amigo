class AddByTesterToIssue < ActiveRecord::Migration
  def change
    add_column :issues, :by_tester, :boolean, default: true
  end
end
