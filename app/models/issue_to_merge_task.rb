class IssueToMergeTask < Task

  ASSIGNED_STATUS = {
      :commited => [1, "提交"],       # 提交
      :opened => [2, "打开"],         # 提交
      :merged => [11, "已合入"],      # 已合入
      :auditing => [12, "待审核"],    # 待审核
      :refused => [7, "拒绝"],        # 拒绝
      :confirming => [13, "待确认"],  # 待确认
      :merging => [14, "待合入"],     # 待合入
      :unmerged => [15, "合入失败"]   # 合入失败
  }

end