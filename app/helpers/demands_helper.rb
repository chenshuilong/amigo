module DemandsHelper
  STATUS_HASH = {"tracked" => "跟踪", "pending" => "挂起", "closed" => "关闭"}
  
  def related_ids_link(related_ids)
    links = []
    ids = related_ids.gsub(/(?!['’ ])\p{P}/, ' ').split(" ").map(&:to_i).uniq.delete_if{|a| a == 0}
    if ids.present?
      actual_ids = Demand.where(id: ids).pluck(:id)
      ids.sort.each do |id|
        link = actual_ids.include?(id) ? link_to(id, demand_path(id)) : id
        links << link
      end
    else
      links << ["无"]
    end
    return links.join(",").html_safe
  end

  def demand_details(details)
    strings = []

    details.each do |detail|
      strings << show_demand_details(detail)
    end
    strings
  end

  def show_demand_details(detail)
    changed = false

    case detail.prop_key
    when "notes"
      label = l(:spec_note)
      value = simple_format(detail.value)
      changed = true
    when "status"
      label = l(:field_status)
      old_value = STATUS_HASH[detail.old_value]
      value = STATUS_HASH[detail.value]
      changed = true
    when "feedback_at"
      label = l(:demand_feedback_at)
      old_value = detail.old_value
      value = detail.value
      changed = true
    when "category_id", "sub_category_id"
      label = l("demand_#{detail.prop_key}".to_sym)
      if detail.prop_key == "category_id"
        old_value = DemandCategory.find_by(id: detail.old_value.to_i).try(:name)
        value = DemandCategory.find_by(id: detail.value.to_i).try(:name)
      elsif detail.prop_key == "sub_category_id"
        old_value = DemandSourceCategory.find_by(id: detail.old_value.to_i).try(:name)
        value = DemandSourceCategory.find_by(id: detail.value.to_i).try(:name)
      end
      changed = true
    when "description", "method", "related_notes"
      label = l("demand_#{detail.prop_key}".to_sym)
      old_value = simple_format(detail.old_value)
      value = simple_format(detail.value)
      changed = true
    when "related_ids"
      label = l(:demand_related_ids)
      old_value = related_ids_link(detail.old_value)
      value = related_ids_link(detail.value)
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
end
