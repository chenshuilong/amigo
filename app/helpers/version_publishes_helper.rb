module VersionPublishesHelper  
  def notes_text(notes, id)
    notes = notes[0]
    text = ""
      
    text = text + "版本锁定变更:上一个锁定版本为'#{notes[:version_lock][:old]}',当前锁定版本为'#{notes[:version_lock][:new]}';\r\n" if notes[:version_lock].present?
    text = text + "备注更新:\r\n更新前:\r\n#{notes[:remove_notes][:old]};\r\n更新后:\r\n#{notes[:remove_notes][:new]};\r\n" if notes[:remove_notes].present?
    if notes[:version_lock].present? && (notes[:change].present? || notes[:without_apk].present? || notes[:without_content].present?)
      text = text + "<a href='/version_publishes/#{id}/abnormal_report?type=history'>查看异常报告</a>".html_safe 
    end

    if notes[:update].present?
      notes[:update].each do |update|
        text = text + "更新:更新'#{update[:apk_name]}'安全公示信息;"
        text = text + "应用中文名由'#{update[:old_cn_name]}'更新为'#{update[:cn_name]}';"  if update.keys.include?(:old_cn_name)
        text = text + "桌面显示名称由'#{update[:old_desktop_name]}'更新为'#{update[:desktop_name]}';" if update.keys.include?(:old_desktop_name)
        text = text + "功能描述由'#{update[:old_description].to_s.gsub(/\s+/, " ")}'更新为'#{update[:description].to_s.gsub(/\s+/, " ")}';" if update.keys.include?(:old_description)
        text = text + "开发者信息由'#{update[:old_developer]}'更新为'#{update[:developer]}';\r\n" if update.keys.include?(:old_developer)
      end
    end

    if notes[:spm_delete].present?
      text = text + "删除:以下应用已经被删除:" + notes[:spm_delete].map{|a| a[:app_name]}.join(", ")+"\r\n"
    end

    return text
  end

  def remark(version_publish)
    text = version_publish.can_change? ? '当前版本已锁定' : '' 
  end

  def error_notice_class(exist, missing, type)
    unless exist
      klass = "table-row-deleted"
    else
      default_klass = type == "tr" ? "" : "table-row-gray"
      klass = missing ? "table-row-missing" : default_klass
    end
  end

  def change_record_text(change, type)
    case type
    when 'apk'
      content = change[:apk_uploaded] ? "需上传官网" : "非上传官网" 
      content += "<i> "+change[:apk_name].to_s + " </i>缺少基本信息"
    when 'content'
      content = "<i> "+change[:apk_name].to_s + " </i>基础信息内容不全"
    when 'change'
      case change[:type]
      when 'add'
        text = l("version_applist_apk_uploaded_#{change[:apk_uploaded]}".to_sym)
        content = "#{change[:v_name]} 版本新增 <i>#{change[:apk_name]}</i> 为#{text}应用"
      when 'delete'
        text = l("version_applist_apk_uploaded_#{change[:apk_uploaded]}".to_sym)
        content = "当前版本删除 <i>#{change[:apk_name]}</i>, 上一版本 #{change[:v_name]} 中为#{text}应用"
      when 'change'
        old_text = l("version_applist_apk_uploaded_#{change[:old][:apk_uploaded]}".to_sym)
        new_text = l("version_applist_apk_uploaded_#{change[:new][:apk_uploaded]}".to_sym)
        content = "<i>#{change[:apk_name]}</i> 在 #{change[:old][:v_name]} 为#{old_text}应用, 在 #{change[:new][:v_name]} 为#{new_text}应用"
      end
    end

    return content.html_safe
  end
end