module SpecsHelper
  def app_spms(project_id)
    Member.select("users.id spms").users_role_project(project_id, "APP-SPM").where("users.status <> 3").map{|m| link_to_user(User.find(m.spms))}
  end

  def to_user(user_id)
    User.find(user_id)
  end

  def to_record_type(type)
    case type
      when SpecAlterRecord::NEW_RECORD then
        "新增"
      when SpecAlterRecord::UPDATE_RECORD then
        "修改"
      when SpecAlterRecord::DELETE_RECORD then
        "删除"
      when SpecAlterRecord::LOCKED_RECORD then
        "锁定"
      when SpecAlterRecord::RESET_RECORD then
        "设为默认"
      when SpecAlterRecord::COLLECT_RECORD then
        "发送收集"
      when SpecAlterRecord::FREEZED_RECORD then
        "冻结"
      when SpecAlterRecord::COPY_RECORD then
        "复制"
      else
        ""
    end
  end

  def to_prop_key(key)
    case key
      when /spec_name/ then
        "规格名称"
      when /spec_jh_/, /jh_collect_finish_dt/ then
        "计划收集完成时间"
      when /spec_sj_/, /sj_collect_finish_dt/ then
        "实际收集完成时间"
      when /spec_note/ then
        "备注"
      when /mark/ then
        "功能描述"
      when /release_path/ then
        "发布路径"
      when /app_name/, /app_production/ then
        "应用名称"
      when /app_version/ then
        "应用版本"
      when /lock/ then
        "锁定"
      when /freeze/ then
        "冻结"
      when /collect/ then
        "收集规格"
      when /reset/ then
        "默认"
      when /for_new/ then
        "规格类型"
      when /project_id/ then
        "项目"
      when /spec_id/ then
        "规格"
      when /cn_name/ then
        "应用中文名"
      when /desktop_name/ then
        "桌面名称"
      when /developer/ then
        "开发者"
      else
        ""
    end
  end

  def to_app_name(id)
    Production.find(id).name || "" if id
  end

  def to_old_value(key, old_value)
    case key
      when /app_version_id/ then
        old_value.to_i > 0 ? Version.find(old_value).fullname : ""
      when /app_production_id/ then
        old_value.to_i > 0 ? Production.find(old_value).name : ""
      when /lock/,/freezed/ then
        old_value.to_i == 0 ? "否" : "是"
      when /for_new/ then
        "发布方式#{old_value}"
      when /project_id/ then
        old_value.to_i > 0 ? Project.find(old_value).name : ""
      when /spec_id/ then
        old_value.to_i > 0 ? Spec.find(old_value).name : ""
      when /spec_copy_type/ then
        old_value.to_i > 0 ? (old_value.to_i == 1 ? "完全复制" : "仅复制应用") : ""
      else
        old_value
    end
  end

  def app_editable?(production_id)
    User.current.is_app_spm?(Production.find(production_id))
  end

  def app_name(project)
    project.show_by(4) ? project.identifier.titleize.split(/\s+/) : project.identifier.upcase
  end

  def release_type_description
    %(
      <ul>
        <li>发布方式1<br>部分上传方式，Android.mk由软件负责人维护，发布系统只更新apk和releasenote</li>
        <li>发布方式2<br>全部上传方式，将发布应用的zip包里全部内容上传，Android.mk由应用维护</li>
        <li>发布方式3<br>应用内容不再上传，只更新版本号到yaml文件</li>
      </ul>
      <p style='color:red;'>注:以上方式选择需和软件负责人沟通确认下</p>
     )
  end

  def copy_type_description
    %(
      <ul>
        <li>完全复制<br>复制所选规格下的所有应用的所有信息(应用版本+功能描述+发布路径)</li>
        <li>仅复制应用<br>复制所选规格下的所有应用</li>
      </ul>
      <p style='color:red;'>注:被复制的规格需要被锁定，才能被复制；默认不选择复制的规格就不会复制规格；</p>
     )
  end

  def compare_text_class(app, specs)
    s_count = specs.count
    (app.v_count >= s_count && app.v_uniq > 1) || app.v_count < s_count ? 'text-danger' : '' 
  end

  def project_specs(project_id)
    Project.find(project_id).specs.map{|spec| spec.project.name + spec.name}
  end
end
