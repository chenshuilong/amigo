module OkrsHelper
  include Redmine::Export::PDF::OkrsPdfHelper

  def status_text
    status_text = [[l(:label_all), '']]
    %w(submitted approving self_scoring other_scoring finished).each do |status|
      status_text << [l("okrs_records_status_#{status}".to_sym), status]
    end
    return status_text
  end

  def okrs_links(obj, type=nil)
    case obj.status
    when "submitted"
      link_to obj.title, edit_okr_path(id: obj.id, category: type)
    else
      link_to obj.title, edit_okr_path(id: obj.id, category: type)
    end
  end

  def rend_okr_title(okr, type)
    case type
    when 'my'
      title([l(:label_my_okrs), my_okrs_path], l(:label_okrs_edit))
    when 'index'
      title([l(:label_okrs), okrs_path], l(:label_okrs_search_result))
    end
  end

  def render_okr_edit_page(okr)
    current_user = User.current
    case okr.status
    when 'submitted', 'failed'
      page = current_user.id == okr.author_id ? 'edit_form' : 'edit_table'
    else
      page = 'edit_table'
    end
    render :partial => page
  end

  def okr_year_option_for_select(obj)
    year = obj.new_record? ? Time.now.year : obj.year_of_title
    options_for_select(((Time.now.year-5)..(Time.now.year+5)).to_a, year)
  end

  def okr_month_option_for_select(obj)
    month = obj.new_record? ? Time.now.month : obj.month_of_title
    options_for_select((1..12).to_a, month)
  end

  def okr_dept_option_for_select(obj)
    dept_id = obj.new_record? ? (User.current.dept.try(:id) || '') : obj.dept_of_title
    @depts = Dept.get_dept_tree_by_orgNo(["10100001"])
    options_for_select(@depts, dept_id)
  end

  def supported_option_for_select(obj)
    support_ids = obj.supports.map(&:user_id)
    supports = obj.supports.pluck(:user_name, :user_id)
    options_for_select supports, support_ids
  end

  def render_ork_tbody(okr, obj)
    current_user = User.current
    html = ""
    html = html + "<tr><td rowspan=#{obj[:results_count]} class='showcontextmenu' data-type='object' data-id=#{obj[:id]}>#{obj[:name]}</td>"
    obj[:results].each do |result|
      html = html + "<tr>" if result[:index].to_i != 0
      html = html + "<td class='showcontextmenu' data-type='result' data-id=#{result[:id]}>#{simple_format(result[:name])}</td>"
      html = html + "<td>#{result[:supported_by]}</td>"
      self_editable = okr.status == "self_scoring" && okr.author_id == current_user.id
      other_editable = okr.status == "other_scoring" && okr.approver_id == current_user.id
      if %w(self_scoring other_scoring finished).include?(okr.status)
        html = html + "<td class='result_score' id='result-self-score-#{result[:id]}' data-id=#{result[:id]} data-bool=#{self_editable} data-info='self-score'>#{result[:self_score]}</td>"
      end
      if %w(other_scoring finished).include?(okr.status)
        html = html + "<td class='result_score' id='result-other-score-#{result[:id]}' data-id=#{result[:id]} data-bool=#{other_editable} data-info='other-score' >#{result[:other_score]}</td>"
      end
      html = html + "</tr>"
    end
    return html.html_safe
  end

  def okrs_details(details)
    strings = []

    details.each do |detail|
      strings << show_okrs_details(detail)
    end
    strings
  end

  def show_okrs_details(detail)
    changed = false

    case detail.prop_key
    when "notes"
      label = l(:field_notes)
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

  def render_okr_desc
    render :partial => 'description'
  end
end
