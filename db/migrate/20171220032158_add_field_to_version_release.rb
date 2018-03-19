class AddFieldToVersionRelease < ActiveRecord::Migration
  def change
    add_column :version_releases, :translate_sync, :integer             # 各种语言翻译是否同步记录
    add_column :version_releases, :output_record_sync, :integer         # 是否同步输出记录表
    add_column :version_releases, :app_data_test, :integer              # 应用流量测试
    add_column :version_releases, :app_launch_test, :integer            # 应用自启测试
    add_column :version_releases, :translate_autocheck_result, :integer # 翻译自检结果

    # Andriod platform for project
    add_column :projects, :android_platform, :integer

    # Category for VersionNameRule
    add_column :version_name_rules, :android_platform, :integer
  end
end
