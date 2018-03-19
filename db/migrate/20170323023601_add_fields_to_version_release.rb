class AddFieldsToVersionRelease < ActiveRecord::Migration
  def change
    add_column :spec_versions, :release_path, :text              #发布路径

    add_column :version_releases, :server_version, :string       #服务器版本
    add_column :version_releases, :validation_results, :string   #验证结果
    add_column :version_releases, :other_app, :string            #需要项目平台解决问题是否提交CR
    add_column :version_releases, :note_one, :text               #功能变更
    add_column :version_releases, :note_two, :text               #变更内容
    add_column :version_releases, :status, :integer, default: 0  #发布状态
  end
end
