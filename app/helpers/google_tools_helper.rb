module GoogleToolsHelper
  def render_tool_url(tool)
  	tool_urls = tool.tool_urls
  	links = []
    options = {}
    items = tool.get_tool_url_type
    items.each do |item|
      next unless tool_urls[item].present?
      next if tool_urls[item]["total_count"].to_i == 0
      if tool_urls[item]["total_count"] == tool_urls[item]["uploaded_count"]
        if tool_urls[item]["total_count"] == 1
          url = tool_urls[item]["urls"][0][:url].to_s
        else
          url = void_js
          options = {onclick: "javascript: showRemoteUrl('#{item.upcase}', #{tool_urls[item]['urls'].to_json});"}
        end
      elsif tool_urls[item]
        url = void_js
        options = {onclick: "layer.msg('文件处理中, 暂时不提供下载...')"}
      end
      links << link_to(item.upcase, url, options)
    end
    return links.join("/").html_safe
  end
end
