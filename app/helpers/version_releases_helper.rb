module VersionReleasesHelper

  def app_production_options_for_select(release)
    default = release.project_id
    productions = Production.where(:production_type => [1,2,3])
    options_from_collection_for_select(productions, :id, :name, default)
  end

  def app_spec_options_for_select(release)
    default = release.spec_id
    producution = release.version.try(:project) || Production.first
    specs = producution.specs.undeleted
    options_from_collection_for_select(specs, :id, :name, default)
  end

  def app_version_options_for_select(release)
    default = release.version_id
    scope = release.version.try(:spec).try(:versions) || (release.version.try(:project) || Production.first).specs.first.try(:versions) || Version.none
    versions = scope.releasable(release.class.consts[:category].invert[release.category])
    options_from_collection_for_select(versions, :id, :name, default)
  end

  def release_heading(release)
    h("#{load_value(release, :category)} -- #{release.version.try(:fullname)}")
  end

  def render_release_result(release)
    results = release.result
    results.map do |result|
      result = result.inject({}){|r, (k, v)| r[k.to_sym] = v; r} unless result.keys.first.is_a?(Hash)
      release_status = if result[:status].zero?
        content_tag :span, l(:version_release_result_fail), class: "tag tag-danger"
      else
        content_tag :span, l(:version_release_result_success), class: "tag tag-success"
      end
      content_tag :div, release_status +
        content_tag(:span, %(#{l(:version_release_path)}: #{result[:uri]})) + (
        link_to(
          l(:version_release_result_view_log), void_js,
          :data => {:log => release.is_a?(Thirdparty) ? view_log_thirdparty_version_release_url(release, result[:log]) : view_log_version_release_url(release, result[:log])},
          :class => "view_release_log"
        ) if result[:log].present? )
    end.join.html_safe
  end

  def avaliable_statues(release)
    release.allowed_statuses.map do |status|
      [l("version_release_status_#{status.to_s}"), status]
    end
  end

  def project_options_for_select
    options_for_select Project.active.where(:category => [1, 2, 3]).pluck(:name, :id)
  end


  def render_tested_mobile(release)
    value = release.tested_mobile
    if value.size == value.scan(/\d+/).sum(&:size) + value.count(',')
      ids = value.scan(/\d+/)
      Project.where(:id => ids).pluck(:name).join(', ')
    else
      value
    end
  end

  def render_failed_count(release)
    return '-' unless release.completed?

    release_count = release.failed_count.to_i
    if release_count > 0
      content_tag :span, l(:version_release_failed_count_with_number, :num => release_count ), class: 'text-danger'
    else
      content_tag :span, l(:version_release_failed_count_all_successfully), class: 'text-success'
    end
  end

  def render_just_adapted(release)
    return '-' unless release.category == release.class.consts[:category][:adapt]

    if release.parent_id.present?
      content_tag :span, l(:general_text_No)
    else
      content_tag :span, l(:general_text_Yes), class: 'text-danger'
    end
  end

  def render_flow_tips(release)
    return if !release.flow? || release.can_flow?
    if release.submitted?
      user = release.ued_user
    elsif release.ued_accepted? || release.ued_half_accepted?
      user = release.sqa_user
    end

    return if user.nil?
    content_tag :p, :class => 'flash warning text-center' do
      l(:version_release_wait_for_next_user, :user => link_to_user(user)).html_safe
    end
  end

  def options_for_failed_count_select
    options_for_select([
      [l(:version_release_failed_count_all_successfully), 0],
      [l(:version_release_failed_count_not_all_successfully), 1]
    ].unshift([l(:label_all), '']), @failed_count)
  end

  def add_note_area(name, options = {})
    name = "version_release_note[#{name.to_s}]"
    opts = options.merge(style: 'height: 65px; display: block')
    text_area_tag name, nil, opts
  end

  def load_value_and_reason(release, attr_name)
    reason =  release.additional_note[attr_name.to_s]
    reason_text = (' (%s)' % reason) if reason.present?
    load_value(release, attr_name).to_s + reason_text.to_s
  end

  def link_to_comlete_project
    release_parent = @release.parent
    if release_parent
      project = release_parent.aimed_project
      project.present?? link_to_project(project) : release_parent.tested_mobile
    else
      '-'
    end
  end

  def link_to_comlete_version
    version = @release.parent.try(:version)
    version.present?? link_to_version(version) : '-'
  end

  def default_value_if_flow_to_sqa
    return unless @release.may_flow_to_sqa?
    <<~TEXT
      - 是否有关联的应用/关联ID？（有则填写应用名称/ID）
      - 是否执行了全功能测试，若没进行全功能测试，是否说明了原因？（功能测试结果作为附件一同上传阿米哥）
      - 代码是否全部Review？
      - 脑图是否同步更新？（有功能变更的需将更新后的脑图作为附件上传阿米哥）
      - 是否有需要项目平台解决问题，是否提交ID？
      - SDK引入评审结果是否OK？（需将评审结果作为附件上传阿米哥）？
      - 安全能力(工信部所要求检查的权限)是否OK？（测试结果需作为附件上传阿米哥）
      - 是否进行流畅度测试？（测试结果需作为附件上传阿米哥）
      - 是否进行响应时间测试？（测试结果需作为附件上传阿米哥）
      - 是否进行待机功耗测试？（测试结果需作为附件上传阿米哥）
      - 是否执行monkey 12小时测试，若没进行，是否说明了原因？（测试结果需作为附件上传阿米哥）
      - 是否执行内存泄露测试，若没进行，是否说明了原因？（测试结果需作为附件上传阿米哥）
      - 是否执行了CTS/CTS verifier测试；（测试结果需作为附件上传阿米哥）
      - 是否说明了功能变更及风险说明（新增和删减）？
      - 修改问题是否说明？
      - 遗留问题不影响版本合入？
      - UED效果是否通过？
      - 全功能测试结果，脑图，SDK评审结果，安全能力测试结果，流畅度，响应时间，待机功耗，monkey，内测泄漏，CTS，CTS verifier，11项测试检查结果是否齐全？
      - 功能测试报告、流畅度、响应时间、somar代码检查结果、新SDK评审结果、内部逻辑图、模块关系图、安全能力测试结果、应用待机功耗报告、monkey测试报告、内存泄漏测试报告、CTS测试报告、CTS verfier测试结果、发布自检表附件是否完整，结果是否OK？
    TEXT
  end

end
