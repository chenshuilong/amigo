class AddColumnToThirdparty < ActiveRecord::Migration
  def change
    add_column :thirdparties, :release_type, :integer
    
    Thirdparty.preload_apps.each do |tdp|
      tdp.release_type = 1
      tdp.save
    end
  end
end
