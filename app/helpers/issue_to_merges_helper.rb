module IssueToMergesHelper
  def approve_merge_task(issue)
    Task.find_by_container_type_and_container_id(issue.issue_type, issue.id) if issue.is_a?(IssueToApproveMerge)
  end

  def task_status_to_name(issue)
    (task = approve_merge_task(issue)).present? ? IssueToApproveTask::ASSIGNED_STATUS.select{|k,v| k.to_s == task.status.to_s}.values[0][1] : ""
  end

  def repo_request_merge_details(issue_to_merge)
    merged_details = Task::TASK_STATUS[:fullmerged][1].to_s
    if issue_to_merge.is_a?(IssueToApproveMerge) && issue_to_merge.repo_request_ids.present?
      repos = JSON.parse(issue_to_merge.repo_request_ids)
      if repos.find_all{|repo| repo["merge_result"] != "SUCCESS"}.present?
        merged_details = "未完全合入" if repos.find_all{|repo| repo["merge_result"] != "SUCCESS"} != repos
      else
        merged_details = "完全未合入"
      end
    end
    merged_details
  end

  def render_merged_repos(issue_to_merge)
    results = issue_to_merge.repo_request_ids ? JSON.parse(issue_to_merge.repo_request_ids) : []
    results.map do |result|
      content_tag :div, RepoRequest.find(result["repo_request_id"]).fullpath
    end.join.html_safe
  end
end
