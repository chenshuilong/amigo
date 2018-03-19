module PatchesHelper
  def render_patch_notes(record, patch)
    html = ""
    details = record.details
    if details.present? 
      content = ""
      details = record.details
      if details.present?
        details.each do |detail|
          content << content_tag(:p, detail.value)
        end
      end
      html = content_tag(:div, format_time(record.created_at) + ' ' + record.notes.to_s, class: 'note-title')
      html += content_tag(:div, content.html_safe, class: 'note-content')
    else
      html = content_tag(:div, format_time(record.created_at) + " #{record.notes}", class: 'note-title')
    end
    html.html_safe
  end

  def patch_lib_title(lib, closed)
    html = ''
    case lib.change_type
    when 'add'
      html = "新增 #{lib.name}"
    when 'delete'
      html = "删除 #{lib.name}"
    when 'modify'
      html = "修改 #{lib.name} "
      html += link_to("文件详情", files_patches_path(library_id: lib.id), remote: true)
    end
    return html.html_safe
  end

  def patch_lib_files(files)
    html = ""
    content = ""
    files.each do |file|
      content << content_tag(:p, "#{file['type']}  #{file['name']}").html_safe
    end
    html = content_tag(:div, content.html_safe, class: "wiki editable")
    return html.html_safe
  end

  def spec_option_for_select(object_ids)
    options_for_select Spec.where(id: object_ids).collect{|a| ["#{a.project.identifier}#{a.name}", a.id]}, object_ids
  end

  def library_file_title(lib)
    status = l("library_status_#{lib.status}")
    html = "Name: #{lib.name} </br> Path: #{lib.path} </br> 状态: #{status} #{link_to('冲突文件', conflict_files_patches_path(lib_id: lib.id), remote:true)}"
    return html.html_safe
  end
end
