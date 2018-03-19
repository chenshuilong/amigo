module IssueToSpecialTestResultsHelper
  def result_link(result)
    name = result.project.name.to_s + '-' + 'T' + '-' + result.id.to_s
    return link_to(name, project_issue_to_special_test_result_path(project_id: result.special_test.project, id: result.id))
  end

  def render_task_tips(task)
  	html = ""
    if task.status == "assigned"
      text = "#{task.assigned_to.firstname}（用例设计者）正在用例设计中"
    elsif task.status == "designed"
      text = "#{task.assigned_to.firstname}（测试执行者）正在测试验证中"
    end

    html = content_tag(:p, text, :class => 'flash warning text-center') if %w(assigned designed).include?(task.status)
    return html.html_safe
  end
end
