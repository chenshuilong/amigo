class AddNotesToApkBase < ActiveRecord::Migration
  def change
    add_column :apk_bases, :notes, :text
  end
end
