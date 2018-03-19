class AddAndroidPlatformToApkBase < ActiveRecord::Migration
  def change
    add_column :apk_bases, :android_platform, :integer
  end
end
