class AddTimeZoneToVersion < ActiveRecord::Migration
  def change
  	add_column :versions, :timezone, :string
  end
end
