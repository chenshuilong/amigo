# -*- encoding : utf-8 -*-
class CustomPermission < ActiveRecord::Base

  belongs_to :user, :foreign_key => 'user_id'
  belongs_to :author, class_name: "User", :foreign_key => 'author_id'

  CUSTOM_PERMISSION_MANAGE = %w(project_branch_judge production_repo_judge project_branch_manage production_branch_manage production_repo_manage)
  CUSTOM_PERMISSION_COMMON = %w(project_branch_apply production_branch_apply production_repo_apply)

  validates_uniqueness_of :user_id, :scope => [:permission_type]
  validates_presence_of :user_id
end
