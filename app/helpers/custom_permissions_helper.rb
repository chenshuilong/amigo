module CustomPermissionsHelper
  PERMISSION_TYPE = {"project_branch_judge" => "项目分支评审", "production_repo_judge" => "产品建仓评审", 
  	                 "project_branch_manage" => "项目分支申请管理权限", "production_branch_manage" => "产品分支申请管理权限",
  	                 "production_repo_manage" => "产品建仓申请管理权限", "project_branch_apply" => "项目分支申请",
                     "production_branch_apply" => "产品分支申请", "production_repo_apply" => "产品建仓申请"}
  
  def scope_text(scope)
    PERMISSION_TYPE[scope]
  end

  def custom_permission_links(obj)
    text = obj.locked ? "解锁" : "锁定"
    link_to text, do_lock_custom_permission_path(obj), class: "btn btn-xs btn-primary"
  end

  def permission_type_options_for_select(list)
    options = []
    list.each do |l|
      options << [PERMISSION_TYPE[l], l]
    end 
    return options
  end
end
