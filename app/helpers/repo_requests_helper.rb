module RepoRequestsHelper
  def project_option_for_select(project_id)
    options_for_select Project.active.where(id: project_id).pluck(:name, :id), project_id
  end

  def version_option_for_select(version_id)
    options_for_select Version.success_versions.where(id: version_id).pluck(:name, :id), version_id
  end

  def users_option_for_select(user_ids)
    options_for_select User.where(id: user_ids).pluck(:firstname, :id), user_ids
  end

  def users_info(users)
    users.each do |user|
      content_tag(link_to_user user)
    end
  end

  def load_users(obj, attribute)
    case attribute
    when :write_users
      users = []
      obj.writer.collect{ |user| users << link_to_user(user)}
      return users.join(', ').html_safe
    when :read_users
      users = []
      obj.reader.collect{ |user| users << link_to_user(user)}
      return users.join(', ').html_safe
    when :submit_users
      users = []
      obj.submitter.collect{ |user| users << link_to_user(user)}
      return users.join(', ').html_safe
    end
  end

  def repo_request_status(request)
    user = User.current
    is_manage = user.can_do?("judge", RepoRequest::REPO_REQUEST_CATEGORY.key(request.category).to_s)
    case request.category
    when 1
      if request.new_record? && request.submitted?
        options = is_manage ? [["提交", "submitted"], ["同意", "agreed"], ["拒绝", "refused"]] : []
      elsif !request.new_record? && request.submitted?
        options = [["同意", "agreed"], ["拒绝", "refused"]]
      end
    when 2
      options = []
    when 3
      if request.new_record? && request.submitted?
        options = is_manage ? [["提交", "submitted"], ["确认", "confirmed"], ["拒绝", "refused"]] : []
      elsif !request.new_record? && request.submitted?
        options = [["确认", "confirmed"], ["拒绝", "refused"]]
      end
    end
  end

  def repo_request_details(details)
    strings = []

    details.each do |detail|
      strings << show_repo_request_details(detail)
    end
    strings
  end

  def show_repo_request_details(detail)
    changed = false

    case detail.prop_key
    when "notes"
      label = l(:spec_note)
      value = simple_format(detail.value)
      changed = true
    end

    if changed 
      label = content_tag('strong', label)
      old_value = content_tag("i", h(old_value)) if old_value.present?
      value = content_tag("i", h(value)) if value.present?

      if old_value.present?
        l(:text_journal_changed, :label => label, :old => old_value, :new => value).html_safe
      else
        l(:text_journal_added, :label => label, :value => value).html_safe
      end
    else
      s = l(:text_journal_changed_no_detail, :label => label)
      s.html_safe
    end
  end

  def repo_request_links(obj)
    case obj.status
    when "submitted"
      link_to l(:button_edit), edit_repo_request_path(id: obj.id), class: "btn btn-xs btn-primary" if obj.can_edit?
    when "agreed"
      link_to l(:button_edit), edit_repo_request_path(id: obj.id), class: "btn btn-xs btn-primary" if obj.can_edit?
    when "successful"
      link_to('废弃', void_js, class: "btn btn-xs btn-primary", id: "abandonRepoRequest", "data-id" => obj.id, "data-content1" => load_value(obj, :use), "data-content2" => obj.branch) if obj.production_type == "china" && obj.author?
    end
  end
end
