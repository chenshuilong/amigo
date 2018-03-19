class CreateIssueToApproveMerges < ActiveRecord::Migration
  def change
    create_table :issue_to_approve_merges do |t|
      t.string   :issue_type         # 1.必合问题:IssueToMerge 2.评审问题:IssueToApprove
      t.integer  :issue_id           # 问题ID
      t.string   :commit_id          # Gerrit提交时的commit_id
      t.text     :branche_ids        # 预计合入流
      t.text     :related_issue_ids  # 关联问题
      t.text     :related_apks       # 关联APK
      t.text     :tester_advice      # 测试建议
      t.text     :dept_result        # 部门审核结论
      t.text     :project_result     # 项目确认结论
      t.text     :master_version_id  # 主干版本
      t.text     :branch_version_ids # 量产流版本
      t.text     :reason             # 原因
      t.text     :requirement        # 要求
      t.text     :notes              # 备注

      t.timestamps null: false
    end

    # Then add a index
    add_index :issue_to_approve_merges, :issue_id
  end
end
