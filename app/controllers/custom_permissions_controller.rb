class CustomPermissionsController < ApplicationController
  before_filter :require_login
  before_action :get_custom_permission, only: [:do_lock]
  before_action :authorize_custom

  helper :sort
  include SortHelper

  layout 'repo'

  def index
    scope = CustomPermission.includes(:user)
    @user = User.current
    if @user.admin?
      @manages = scope.where(permission_type: CustomPermission::CUSTOM_PERMISSION_MANAGE)
      common_scope =  scope.where(permission_type: CustomPermission::CUSTOM_PERMISSION_COMMON)
    else
      manage_list = @user.user_custom_permission_manage.map{|e| e.gsub("_manage", "_apply")}
      common_scope =  scope.where(permission_type: manage_list)
    end

    @limit = per_page_option
    @count = common_scope.count
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @commons = common_scope.limit(@limit).offset(@offset).reorder("created_at desc").to_a
  end

  def new
    @custom_permission = CustomPermission.new
    @user = User.current
    @manages = @user.admin? ? CustomPermission::CUSTOM_PERMISSION_COMMON : @user.user_custom_permission_manage.map{|a| a.gsub("_manage", "_apply")}
    @type = params[:type].present? ? params[:type] : "common"
    render 'new'
  end

  def create
    @custom_permission = CustomPermission.new(custom_permission_params)
    if @custom_permission.save
      respond_to { |format| format.js }
    else
      render :js => 'layer.alert("添加失败！");'
    end
  end

  def do_lock
    @custom_permission.update(locked: !@custom_permission.locked)
    redirect_back_or_default custom_permissions_path
  end

  private

  def custom_permission_params
    params.require(:custom_permission).permit(:user_id, :permission_type, :author_id, :notes)
  end

  def get_custom_permission
    @custom_permission = CustomPermission.find(params[:id])
  end

  def authorize_custom
    allowed = User.current.can_do?("manage", nil)
    if allowed
      true
    else
      render_403 :message => :notice_not_authorized_archived_project
    end
  end
end
