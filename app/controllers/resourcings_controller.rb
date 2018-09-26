class ResourcingsController < ApplicationController
  before_filter :require_login

  layout 'admin'
  menu_item :roles
  # accept_api_auth :index

  def index
    @users = query_user
    respond_to do |format|
      format.js
      format.html{ @rest_count  = @users_all_count - 25 }
    end
  end

  def edit_permission
    user_id  = params[:user_id]
    users_id = _ = params[:user_ids]; _.is_a?(Array) ? _ : _.to_s.split(/\s+/)

    @users = User.where(:id => user_id)  if user_id.present?
    @users = User.where(:id => users_id) if users_id.present?
    @users = (@users || query_user).includes(:resourcing)
    @polices = Resourcing.setable_permissions

    if request.post?
      transitions = params[:permissions].deep_dup
      transitions = transitions.delete_if{|name, value| value == "no_change"}
      Resourcing.replace_transitions(@users, transitions)
      flash[:notice] = l(:notice_successful_update)
      redirect_to resourcings_path
      return
    end
  end

  private

  def query_user
    @category = params[:category]
    @dept_no  = params[:dept_no] || []
    @perms    = params[:permissions] || []
    @name     = params[:name]
    @names    = params[:name].split(",").map(&:strip) if @name && /\,/ === @name
    @page     = params[:page] || 1
    @per_page = 25 if params[:per_page] != "all"

    scope = User.all.active
    scope = scope.category(@category)         if @category.present?
    scope = scope.like(@name)                 if @name.present? && @names.nil?
    scope = scope.where(:firstname => @names) if @names.present?
    scope = scope.where(:orgNo => Dept.find(@dept_no).all_down_depts)   if @dept_no.present?
    scope = scope.where(:id => Resourcing.all.find_all{|res| (res.permissions | @perms.collect{|p| p.to_sym}) == res.permissions}.map(&:user_id))  if @perms.present?

    @users_all_count = scope.count
    scope = scope.limit(@per_page) if @per_page.present?
    scope = scope.order(:id)
  end

end
