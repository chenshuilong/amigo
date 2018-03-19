module ToolsHelper
  def user_option_for_select(user_id)
    options_for_select User.where(id: user_id).pluck(:firstname, :id), user_id
  end

  def tool_links(url, extra_type)
    html = ''
    url.each do |k, v|
      if k.to_s == extra_type
        if v[:status] == "doing"
          html = html + "<span class='text-danger'>文件处理中, 暂时不提供下载...</span>"
        else
          html = html + link_to(l(:tool_click_to_download), v[:url])
        end
      end
    end
    return html.html_safe
  end
end
