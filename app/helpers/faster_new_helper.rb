module FasterNewHelper
  SCOPE_HASH = {"version" => "版本", "project" => "项目", "issue" => "问题", "version_release" => "发布", "production" => "产品"}
  
  def scope_text(type)
    SCOPE_HASH[type]
  end
end
