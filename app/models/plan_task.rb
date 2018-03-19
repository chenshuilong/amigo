class PlanTask < Task
  ASSIGNED_STATUS = {
      :opened => [2, "打开"],         # 打开
      :finished => [4, "完成"],       # 完成
      :refused => [7, "拒绝"]         # 拒绝
  }

  CONFIRM_STATUS = {
      :finished => [5, "已确认"],      # 已确认
      :refused => [7, "拒绝"]          # 拒绝

  }

  SPM_STATUS = {
      :finished => [6, "关闭"],       # 关闭
      :reopened => [3, "重打开"]      # 重打开
  }
end