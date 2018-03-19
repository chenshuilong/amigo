class AddIntegratedToApkBase < ActiveRecord::Migration
  def change
    add_column :apk_bases, :integrated, :boolean
  end
end
