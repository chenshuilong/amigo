module ProductionsHelper
  include ProjectsHelper

  def render_app_roles(members)
    roles_hash = app_roles_hash(members)

    html = ""
    roles_hash.each do |k, v|
    	content = ""
      if v.present?
      	users = []
        v.each do |key, val|
          users << content_tag(:a, val,{:href => user_path(key)})
        end
        content = users.join(", ")
      else
        content += "-"
      end
      html = html + content_tag(:td, content.html_safe)
    end
    return html.html_safe
  end

  def app_roles_hash(members)
    roles_hash = Production::ROLES.collect{|k, v| [v[0], {}]}.to_h

    if members.present?
      members.split("|").each do |member|
        item = member.split(",")
        roles_hash[item[0].to_i] = roles_hash[item[0].to_i].merge!({item[1] => item[2]})
      end
    end
    return roles_hash
  end

  def details_text(r)
    details = r.details
    text = "[编辑] #{r.alter_for.name} "
    details.each do |d|
      case d.prop_key
      when "has_adapter_report"
        old_value = d.old_value.nil? ? '-' : (d.old_value == '1' ? l(:general_text_yes) : l(:general_text_no) ) 
        value = d.value.nil? ? '-' : (d.value == '1' ? l(:general_text_yes) : l(:general_text_no))
        text = text + "#{l(:project_has_adapter_report)} 由 #{old_value} 变成 #{value}; " 
      when "notes"
        old_value = d.old_value
        value = d.value
        text = text + "#{l(:label_remark)} 由 #{old_value} 变成 #{value};"
      end
    end
    return text
  end
end
