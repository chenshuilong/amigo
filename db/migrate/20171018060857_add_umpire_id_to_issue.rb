class AddUmpireIdToIssue < ActiveRecord::Migration
  def change
    add_column :issues, :umpire_id, :integer
  end
end
