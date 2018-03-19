class AddFieldToThirdparty < ActiveRecord::Migration
  def change
    add_column :thirdparties, :category, :integer
    add_column :thirdparties, :release_ids, :text

    Thirdparty.all.each do |tdp|
      tdp.category = Thirdparty::Thirdparty_CATEGORY[:preload]
      tdp.release_ids = tdp.version_ids
      tdp.version_ids = []
      tdp.save
    end
  end
end
