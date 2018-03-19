module IssueToSpecialTestsHelper
  def related_issues(related_issues)
    ids = related_issues.gsub(/[^'’[^\p{P}]]/, " ").split(" ")
    collect = []
    ids.each do |id|
      next if id.to_i == 0
      issue = Issue.find_by(id: id.to_i)
      if issue.present?
        collect << link_to(id, issue_path(id))
      else
        collect << id
      end
    end
    content = collect.join(", ").html_safe
    return content
  end

  def special_link(special)
    name = special.project.name.to_s + '-' + 'R' + '-' + special.id.to_s
    return link_to(name, project_issue_to_special_test_path(project_id: special.project, id: special.id))
  end
end
