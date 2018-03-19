module ReposHelper
  include IssuesHelper

  def category_options_for_select
    ret = ''
    Repo::REPO_CATEGORY.each do |k, v|
      name = l("repo_category_" + k.to_s)
      ret << "<option value='#{v}'>#{name}</option>"
    end
    ret.html_safe
  end

  def repo_options_for_select(category)
    ret = ''
    Repo.select('id, url').where(category: category).find_each().each do |r|
      ret << "<option value='#{r.id}'>#{r.url}</option>"
    end
    ret.html_safe
  end

  def project_repo_options_for_select(project, category, default)
    repos = project.repos.where(:category => category)
    options_from_collection_for_select(repos, :id, :url, default)
  end

  def project_repo_one_options_for_select(project, version)
    type = project.show_by(4) ? :production : :android
    category = Repo::REPO_CATEGORY[type]
    default = version.repo_one_id
    project_repo_options_for_select(project, category, default)
  end

  def project_repo_two_options_for_select(project, version)
    type = project.show_by(4) ? :env : :package
    category = Repo::REPO_CATEGORY[type]
    default = version.repo_two_id
    project_repo_options_for_select(project, category, default)
  end

  def status_class(status)
    {"offline" => "text-danger", "idle" => "text-success"}[status]
  end

  def render_tasks_in_queue(tasks)
    if tasks.present?
      html = '<table><tbody>'
      tasks.each_with_index{|task, index| html << %(<tr><td>#{index + 1}</td><td>#{link_to_version task}</td></tr>)}
      html << '</tbody></table>'
    else
      l(:label_no_data)
    end
  end

  def ReposHelper.get_repos_by_version_id(version_id)
    Repo.get_by_version_id(version_id)
  end
end
