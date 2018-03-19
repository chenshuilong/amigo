module TasksHelper
  def task_status_options(task)
    case task.container_type
    when "PersonalTask"
      if task.author_id == task.assigned_to_id
        case task.status
        when "submitted", "reopened", "executing"
          #options = Task::TASK_STATUS.collect{|key, value| [value[1], value[0]]}.delete_if{|a| ([11, 4, 6]).exclude?(a[1])}
          options = [["执行中", "executing"], ["完成", "finished"], ["关闭", "closed"]]
        when "finished"
        	options = [["关闭", "closed"], ["重打开", "reopened"]]
        end
      else
      	case task.status
      	when "finished", "refused"
          options =  [["关闭", "closed"], ["重打开", "reopened"]]
        when "submitted", "reopened", "executing"
      		options = [["执行中", "executing"], ["完成", "finished"], ["拒绝", "refused"]]
      	end
      end
    when "IssueToSpecialTestResult"
      if task.is_design?
        options = IssueToSpecialTestTask.consts[:status].values.delete_if{|e| e[0] == 4}.collect{|e| [e[1], e[0]]}
      elsif task.is_assign?
        options = IssueToSpecialTestTask.consts[:status].values.delete_if{|e| e[0] == 9}.collect{|e| [e[1], e[0]]}
      end
    when "Library"
      case task.status
      when 'update_failed'
        options = [["分支升级成功", "update_success"]]
      when 'merge_failed'
        options = [["主干合入成功", "merge_success"]]
      when 'push_failed'
        options = [["主干推送成功", "push_success"]]
      end
    when "ApkBase"
      options = [["同意", "agreed"], ["拒绝", "refused"]]
    when "PatchVersion"
      options = task.container.result.present? ? ["PASS"] : [["PASS"], ["NG"]]
    when "LibraryFile"
      options = [['成功','success']]
    end
  end

  def personal_task_details(details)
    strings = []

    details.each do |detail|
      strings << show_personal_task_details(detail)
    end
    strings
  end

  def show_personal_task_details(detail)
    changed = false

    case detail.prop_key
    when "notes"
      label = l(:spec_note)
      value = simple_format(detail.value)
      changed = true
    when "status"
      label = l(:field_status)
      old_value = Task::TASK_STATUS[detail.old_value.to_sym][1]
      value = Task::TASK_STATUS[detail.value.to_sym][1]
      changed = true
    when "start_date", "due_date"
      label = l("plan_#{detail.prop_key}".to_sym)
      old_value = detail.old_value.first(19)
      value = detail.value.first(19)
      changed = true
    when "name", "description"
      label = l("task_#{detail.prop_key}".to_sym)
      old_value = simple_format(detail.old_value)
      value = simple_format(detail.value)
      changed = true
    when "supplement"
      label = l(:label_supplement)
      value = simple_format(detail.value)
      changed = true
    when "assigned_to_id"
      label = l(:task_assigned_to_id)
      old_value = User.find_by(id: detail.old_value.to_i).firstname
      value = User.find_by(id: detail.value.to_i).firstname
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

  def task_authoring_at(created, author, options={})
    author_link = link_to(author, user_path(author), target: options[:target])
    l(options[:label] || :label_added_time_by, :author => author_link, :age => format_time(created)).html_safe
  end

  def related_issues(related_issues)
    ids = related_issues.gsub(/[^'’[^\p{P}]]/, " ").split(" ")
    collect = []
    ids.each do |id|
      next if id.to_i == 0
      issue = Issue.find_by(id: id.to_i)
      if issue.present?
        collect << link_to(id, issue_path(id), target: 'blank')
      else
        collect << id
      end
    end
    content = collect.join(", ").html_safe
    return content
  end
end
