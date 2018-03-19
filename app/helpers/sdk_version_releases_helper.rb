module SdkVersionReleasesHelper
  include ProjectsHelper

  def render_release_projects(sdk)
    (ids = sdk.release_project_ids).blank? ? "-" : Project.where(:id => ids.uniq).pluck(:name).join(', ')
  end

  def render_maven_result(sdk)
    (status = sdk.maven_result[:success]).blank? ? "-" : status.zero? ? l(:version_release_result_fail) : l(:version_release_result_success)
  end

  def render_sdk_type(sdk)
    sdk.version.project.sub_production_type.to_i == Project::PROJECT_SUB_PRODUCTION_TYPE[:app].to_i ? l(:project_sub_production_type_app) : l(:project_sub_production_type_system)
  end

  def render_failed_count(sdk)
    return '-' unless sdk.completed?

    release_count = sdk.failed_count.to_i
    if release_count > 0
      content_tag :span, l(:version_release_failed_count_with_number, :num => release_count ), class: 'text-danger'
    else
      content_tag :span, l(:version_release_failed_count_all_successfully), class: 'text-success'
    end
  end

  def render_maven_release_result(sdk)
    result = sdk.maven_result

    if result.present?
      release_status = if result[:success].zero?
                         content_tag :span, l(:version_release_result_fail), class: "tag tag-danger"
                       else
                         content_tag :span, l(:version_release_result_success), class: "tag tag-success"
                       end

      (content_tag :div, release_status + content_tag(:span, %(#{result[:message]}))).html_safe
    end
  end
end
