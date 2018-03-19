module ApkBasesHelper
    def record_type(property)
    case property
    when "create"
      "新增"
    when "update"
      "修改"
    when "delete"
      "删除"
    end
  end
end
