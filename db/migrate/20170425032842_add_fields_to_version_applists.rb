class AddFieldsToVersionApplists < ActiveRecord::Migration
  def change
    add_column :version_applists, :apk_name, :string # apk名称
    add_column :version_applists, :apk_size, :string # apk大小
    add_column :version_applists, :apk_interior_version, :string # apk内部版本
    add_column :version_applists, :apk_permission, :text # apk权限
    add_column :version_applists, :apk_removable, :boolean # apk是否可卸载

    add_column :versions, :warning, :string # 版本异常警告
  end
end
