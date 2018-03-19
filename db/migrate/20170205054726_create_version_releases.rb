class CreateVersionReleases < ActiveRecord::Migration
  def change
    create_table :version_releases do |t|
      t.integer :category, null: false # 发布类型
      t.references :version, index: true  # 应用版本号
      t.string :version_applicable_to # 版本适用
      t.string :tested_mobile # 测试机型
      t.datetime :test_finished_on #测试时间
      t.integer :author_id #发布人
      t.integer :test_type # 测试类型
      t.integer :bvt_test # BVT测试
      t.integer :fluency_test # 流畅度测试
      t.integer :response_time_test # 响应时间
      t.integer :sonar_codes_check # sonar代码检查
      t.integer :app_standby_test # 应用待机功耗测试
      t.integer :monkey_72_test # monkey 72小时测试
      t.integer :memory_leak_test # 内存泄露测试
      t.integer :cts_test # CTS测试
      t.integer :cts_verifier_test # CTS校验测试
      t.integer :interior_invoke_warning # 安全能力——应用调用使用权限提示
      t.integer :related_invoke_warning # 安全能力——关联应用调用使用权限提示
      t.string :relative_objects # 关联应用/关联问题ID
      t.boolean :codes_reviewed # 代码是否全部Review
      t.boolean :cases_sync_updated # case是否同步更新
      t.string :issues_for_platform # 需平台解决问题
      t.boolean :code_walkthrough_well # 代码走查结果是否良好
      t.text :failed_info # 发布失败原因
      t.string :path # 发布路径
      t.integer :mode # 发布方式
      t.integer :sdk_review # SDK引入评审结果
      t.text :description # 描述
      t.text :remaining_issues # 遗留问题
      t.text :new_issues # 新增问题
      t.integer :ued_confirm # UED效果确认
      t.text :note # 备注
      t.integer :uir_upload_to_svn # UIR是否已上传SVN
      t.timestamps null: false
    end
  end
end
