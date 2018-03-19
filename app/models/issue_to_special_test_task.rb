class IssueToSpecialTestTask < Task
  ISSUE_TO_SPECIAL_TEST_TASK_STATUS = {
    :assigned => [9, "分配"],
    :designed => [10, "设计完成"],
    :finished => [4, "完成"]
  }
end