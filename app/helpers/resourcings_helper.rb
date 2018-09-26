module ResourcingsHelper

  def list_for_user_category
    category = User::CATEGORY
    options = category.map{|cate| [l("user_category_#{cate}"), cate]}.unshift([l(:label_all), ""])
    options_for_select(options, @category)
  end

  def list_for_depts
    Dept.options_group_for_select
  end

  def list_for_permissions
    Resourcing.setable_permissions.group_by(&:block).collect{|parent, children|
      block_name = l("resourcing_block_#{parent.to_s}")
      ["<optgroup label=\"#{block_name}\" >", children.map{|c| "<option value=\"#{c.name.to_s}\">&nbsp;&nbsp;&nbsp;&nbsp;#{l(c.label)}</option>"}]
    }.flatten.uniq
  end

  def render_set_user_notice
    user_text = if @users.size <= 5
      @users.map(&:name).join(", ")
    else
      @users.take(5).map(&:name).join(", ") + "等（共<span class='text-danger'>#{@users.length}</span>人）"
    end
    "为 #{user_text} 设置全局权限".html_safe
  end

  def current_get_params
    request.GET.merge(:per_page => "all").except(:utf8)
  end

  def have_permission?(user, permission)
    user.resourcing.present? && user.resourcing.permissions.include?(permission.name)
  end

  def permissions_tag(permission, users)
    name       = permission.name.to_s
    user_count = users.length
    has_permission = -> (user, p) {  }
    if user_count <= 1
      hidden_field_tag("permissions[#{name}]", 0) +
      check_box_tag("permissions[#{name}]", 1, have_permission?(users.first, permission), :id => "permissions_#{name}")
    else
      tag_value =  permissions_tag_value(permission, users)
      if tag_value == "no_change"
        select_tag "permissions[#{name}]", options_for_select([
            [l(:general_text_Yes), "1"],
            [l(:general_text_No), "0"],
            [l(:label_no_change_option), "no_change"]
          ], "no_change"), :id => "permissions_#{name}"
      else
        hidden_field_tag("permissions[#{name}]", 0) +
        check_box_tag("permissions[#{name}]", 1, tag_value, :id => "user_permissions_#{name}")
      end
    end
  end

  def permissions_tag_value(permission, users)
    have   = users.all?{|user| have_permission?(user, permission)}
    nohave = users.all?{|user| !have_permission?(user, permission)}

    return "no_change" if !have && !nohave
    return true  if have
    return false if nohave
  end

end
