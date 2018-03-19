class AddApkUploadedToVersionApplist < ActiveRecord::Migration
  def change
    add_column :version_applists, :apk_uploaded, :boolean
  end
end
