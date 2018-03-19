class IssueToApproveTask < Task

  ASSIGNED_STATUS = {
      :submitted => [1, "提交"],      # 提交
      :merged => [11, "已合入"],      # 已合入
      :refused => [7, "拒绝"]         # 拒绝
  }

end