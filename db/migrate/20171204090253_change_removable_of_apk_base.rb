class ChangeRemovableOfApkBase < ActiveRecord::Migration
  def self.up
    change_column :apk_bases, :removable, :string
  end

  def self.down
    change_column :apk_bases, :removable, :boolean
  end
end
