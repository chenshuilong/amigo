module IssueToApprovesHelper
  def approve_merge_task(issue)
    Task.find_by_container_type_and_container_id(issue.issue_type, issue.id) if issue.is_a?(IssueToApproveMerge)
  end

  def task_status_to_name(issue)
    (task = approve_merge_task(issue)).present? ? IssueToApproveTask::ASSIGNED_STATUS.select{|k,v| k.to_s == task.status.to_s}.values[0][1] : ""
  end
end
