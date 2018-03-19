class AddHasUnitTestReportToVersion < ActiveRecord::Migration
  def change
    add_column :versions, :has_unit_test_report, :boolean, :default => false
  end
end
