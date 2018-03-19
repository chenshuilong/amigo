class AddMoreFiledsToVersion < ActiveRecord::Migration
  def change
    change_column :versions, :status, :integer, default: 1 #更改状态字段的类型
    add_column :versions, :repo_one_id, :integer # 安卓代码库/ APK代码库/ 通信模块代码库/ 框架代码库
    add_column :versions, :repo_two_id, :integer # 包代码库/ APK环境代码库/ 基础环境代码库
    add_column :versions, :repo_three_id, :integer # 预留字段
    add_column :versions, :priority, :integer # 编译优先级
    add_column :versions, :compile_status, :integer # 编译状态
    add_column :versions, :last_version_id, :integer # 上一个版本
    add_column :versions, :log_url, :string # Log链接
    add_column :versions, :compile_type, :integer # 编译版本的类型
    add_column :versions, :ota_whole_compile, :boolean # OTA整包编译
    add_column :versions, :ota_increase_compile, :boolean # OTA差分包编译
    add_column :versions, :ota_increase_versions, :string # 需要差分的版本
    add_column :versions, :as_increase_version, :boolean # 作为基础差分版本
    add_column :versions, :signature, :boolean # 签名
    add_column :versions, :spec_id, :integer # 规格
    add_column :versions, :continue_integration, :boolean # 持续集成（自动化）
    add_column :versions, :arm, :integer # ARM运算位数
    add_column :versions, :strengthen, :boolean # 强化处理
    add_column :versions, :auto_test, :boolean # 自动化测试
    add_column :versions, :unit_test, :boolean # 单元测试
    add_column :versions, :auto_test_projects, :string # 自动化测试项目
    add_column :versions, :sonar_test, :boolean # Sonar测试
    add_column :versions, :parent_id, :integer # 大版本ID，大版本时为空
    add_column :versions, :compile_machine, :string # 编译机号
    add_column :versions, :author_id, :integer # 提交人
    add_column :versions, :rom_project_id, :integer # 终端项目，用于框架或通信模块
    add_column :versions, :stopped_user_id, :integer # 中止编译人
    add_column :versions, :compile_stop_on, :datetime # 编译中止时间
    add_column :versions, :compile_start_on, :datetime # 编译开始时间
    add_column :versions, :compile_end_on, :datetime # 编译结束时间
    add_column :versions, :compile_due_on, :datetime # 计划编译时间
  end
end
