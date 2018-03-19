class AddSendtestAtToVersion < ActiveRecord::Migration
  def change
    add_column :versions, :sendtest_at, :datetime
  end
end
