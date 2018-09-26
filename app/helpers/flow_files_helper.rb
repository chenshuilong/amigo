module FlowFilesHelper
  def author_option_for_select(ids)
    options_for_select User.where(id: ids).pluck(:firstname, :id), ids
  end

  def attachments_option_for_select(file, ids=nil)
    ids = file.flow_file_attachments.where(status: "active").map(&:attachment_id) if ids.blank?
    options_for_select Attachment.where(id: ids).pluck(:filename, :id), ids
  end

  def flow_file_attachments_link(file)
    links = []
    file.flow_file_attachments.where(status: %w(active abandoned)).includes(:attachment).each do |ffa|
      atta = ffa.attachment
      filename = atta.filename
      filename = filename + " (废弃)" if ffa.status == 'abandoned'
      path = atta.ftp_ip.present? ? File.join(Attachment::IPS[atta.ftp_ip.to_s][:ftp], "#{atta.container_id}/#{atta.id}/#{atta.disk_filename}") : void_js
      links << link_to(filename, path)
    end

    return links.join("</br>").html_safe
  end

  def attachments_link(file)
    links = []
    @file.attachments.where(deleted: false).each do |atta|
      path = atta.ftp_ip.present? ? File.join(Attachment::IPS[atta.ftp_ip.to_s][:ftp], "#{atta.container_id}/#{atta.id}/#{atta.disk_filename}") : void_js
      links << link_to(atta.filename, path)
    end

    return links.join("</br>").html_safe
  end

  def change_details(details)
    strings = []

    details.each do |detail|
      strings << show_change_details(detail)
    end
    strings
  end

  def show_change_details(detail)
    changed = false

    case detail.prop_key
    when "name"
      label = l(:flow_file_name)
      old_value = detail.old_value
      value = detail.value
      changed = true
    when "version"
      label = l(:flow_file_version)
      old_value = detail.old_value
      value = detail.value
      changed = true
    when "file_type_id"
      label = l(:flow_file_file_type_id)
      old_value = FlowFileType.find_by(id: detail.old_value).try(:name)
      value = FlowFileType.find_by(id: detail.value).try(:name)
      changed = true
    when "file_status_id"
      label = l(:flow_file_file_status_id)
      old_value = FlowFileStatus.find_by(id: detail.old_value).try(:name)
      value = FlowFileStatus.find_by(id: detail.value).try(:name)
      changed = true
    when "attachment"
      label = l(:flow_file_attachments)
      atta = Attachment.find_by(id: detail.value)
      path = atta.ftp_ip.present? ? File.join(Attachment::IPS[atta.ftp_ip.to_s][:ftp], "#{atta.container_id}/#{atta.id}/#{atta.disk_filename}") : void_js
      atta_path = link_to(atta.try(:filename), path)
      value = "<strong>"+l("flow_file_attachments_#{detail.property}".to_sym)+"</strong>" + " <i>#{label}</i> #{atta_path}"
      changed = true
    when "flow_file_attachment"
      label = l(:flow_file_flow_file_attachments)
      atta = Attachment.find_by(id: detail.value)
      path = atta.ftp_ip.present? ? File.join(Attachment::IPS[atta.ftp_ip.to_s][:ftp], "#{atta.container_id}/#{atta.id}/#{atta.disk_filename}") : void_js
      atta_path = link_to(atta.try(:filename), path)
      value = "<strong>"+l("flow_file_attachments_#{detail.property}".to_sym)+"</strong>" + " <i>#{label}</i> #{atta_path}"
      changed = true
    when "use"
      label = l(:flow_file_use)
      old_value = simple_format(detail.old_value)
      value = simple_format(detail.value)
      changed = true
    when "flow_file_delete"
      ffa = FlowFileAttachment.find_by(id: detail.value)
      atta = ffa.attachment
      path = atta.ftp_ip.present? ? File.join(Attachment::IPS[atta.ftp_ip.to_s][:ftp], "#{atta.container_id}/#{atta.id}/#{atta.disk_filename}") : void_js
      value = "相关附件 #{link_to(atta.filename, path)} 关联的流程文件被删除, 状态变为 <strong>废弃</strong>"
      changed = true
    when "flow_file_abandon"
      ffa = FlowFileAttachment.find_by(id: detail.value)
      atta = ffa.attachment
      flow_file = FlowFile.find_by(id: ffa.parent_flow_file_id)
      path = atta.ftp_ip.present? ? File.join(Attachment::IPS[atta.ftp_ip.to_s][:ftp], "#{atta.container_id}/#{atta.id}/#{atta.disk_filename}") : void_js
      value = "流程文档 #{link_to(flow_file.try(:name), flow_file_path(ffa.parent_flow_file_id))} 被废弃, 相关附件 #{link_to(atta.filename, path)} 状态变为 <strong>废弃</strong>"
      changed = true
    end

    if changed 
      label = content_tag('strong', label)

      if %w(attachment flow_file_attachment flow_file_delete flow_file_abandon).include?(detail.prop_key)
        value.html_safe
      else
        old_value = content_tag("i", h(old_value)) if old_value.present?
        value = content_tag("i", h(value)) if value.present?
        if old_value.present?
          l(:text_journal_changed, :label => label, :old => old_value, :new => value).html_safe
        else
          l(:text_journal_added, :label => label, :value => value).html_safe
        end
      end
    else
      s = l(:text_journal_changed_no_detail, :label => label)
      s.html_safe
    end
  end
end
