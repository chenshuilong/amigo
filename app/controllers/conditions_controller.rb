class ConditionsController < ApplicationController

  include IssuesHelper
  include QueriesHelper
  before_action :check_admin_when_create_system_filter, only: [:create]
  before_action :check_auth_user, only: :destroy
  before_action :check_condition_folder_id_legal, only: [:create, :update]

  def create
    @condition = User.current.conditions.new(condition_params)
    respond_to do |format|
      format.json {
        if @condition.save
          ReportCondition.create({:condition_id => @condition.id, :json => params[:condition][:report_conditions] || ""})
          render :json => @condition.id, :status => :ok
        else
          render :json => nil, :status => :unprocessable_entity
        end
      }
    end
  end

  def update
    @condition = Condition.find_by_id(params[:id])
    keep_update = bool_of params[:keep_update]
    if (current_user_of(@condition) || User.current.admin) && keep_update # Update User Condition or System Condition
      @condition.update_attributes(condition_update_params)
    elsif current_user_of(@condition) && !keep_update # Copy User Condition
      @condition = @condition.dup
      @condition.update_attributes(condition_update_params) if params[:condition].present?
      @condition.update_attribute(:name, @condition.name.to_s + "- 副本")
    elsif [Condition::STATUS_ISSUE_SYSTEM, Condition::STATUS_REPORT_SYSTEM].include?(@condition.category) && !keep_update  # Send to System Conditon to user
      @condition = @condition.dup
      @condition.update_attributes(condition_update_params) if params[:condition].present?
      @condition.update_attributes({:category => params[:category] || 1, :folder_id => nil, :user_id => User.current.id})
    else
      @condition = nil
    end
    @condition.report_condition.update_attributes({:json => params[:condition][:report_conditions] || ""}) if @condition && @condition.report_condition
    respond_to do |format|
      format.json {
        render :json => @condition.id, :status => :ok
      }
    end
  end


  def destroy
    @condition = Condition.find(params[:id])
    @condition.destroy
    respond_to do |format|
      format.json {
        render :json => nil, :status => :ok
      }
    end
  end

  def conditionvalue
    key = params[:key]
    @value = condition_json_for_select(key)
    render :text => @value.to_json
  end

  def conditioncolumn
    # retrieve_query
    # columns = @query.available_columns.collect {|column| {:text => column.caption, :for => column.name.to_s}}
    # columns.delete_at(0) #Remove ID
    last_columns = User.current.conditions.column_order_last
    last_columns = last_columns.column_order if last_columns.present? && last_columns.column_order.present?
    render :json => condition_column_order(last_columns)
  end

  def conditioninfo
    condition = Condition.find_by_id(params[:id])
    name = condition.name
    json = condition.json
    possible_users = condition.possible_users.map{|u| [u.id, u.name]}
    possible_users << ['me', "<< #{l(:label_me)} >>"] # add option: 'me'
    columns = condition.column_order || ""
    column_order = condition_column_order(columns)
    column_count = columns.split(",").count
    info = {:name => name, :column_order => column_order, :column_count => column_count, :json => json, :users => possible_users}
    render json: info
  end

  def conditionshare
    condition = Condition.find_by_id(params[:condition_id])
    if condition.present? && condition.user == User.current && condition.is_personal?
      user_ids = params[:share][:user_ids]
      dept_ids = params[:share][:dept_ids]
      cate = params[:category] || "condition"
      Notification.share_condition(cate, condition, user_ids, dept_ids)
      render :js => "layer.msg('分享成功！')"
    else
      render :js => "layer.alert('分享失败！')"
    end
  end

  private

  def current_user_of(condition)
    # condition.category == 1 && condition.user == User.current
    [Condition::STATUS_ISSUE_STAR, Condition::STATUS_REPORT_STAR].include?(condition.category) && condition.user == User.current
  end

  def bool_of(param)
    param == "true"
  end

  def condition_params
    params.require(:condition).permit(:category, :name, :is_folder, :folder_id, :column_order, :project_id, :json)
  end

  def condition_update_params
    params.require(:condition).permit(:name, :is_folder, :folder_id, :column_order, :project_id, :json)
  end

  def check_auth_user
    @condition = Condition.find_by_id(params[:id])
    if @condition.blank? || !category_one_or_admin_user(@condition)
      head :forbidden
    end
  end

  def check_condition_folder_id_legal
    return true if params[:keep_update] == "false"
    folder_id = params[:condition][:folder_id]
    return true if folder_id.blank?
    condition = Condition.find(folder_id)
    if condition.present? && condition.is_folder? && category_one_or_admin_user(condition)
      return true
    else
      head :forbidden
    end
  end

  def check_admin_when_create_system_filter
    cate = params[:condition][:category]
    # if (cate == 2 && !User.current.admin?)
    if ([Condition::STATUS_ISSUE_SYSTEM,Condition::STATUS_REPORT_SYSTEM].include?(cate) && !User.current.admin?)
      head :forbidden
    else
      return true
    end
  end

  def category_one_or_admin_user(condition)
    # (condition.category == 1 && condition.user == User.current) || (condition.category == 2 && User.current.admin?)
    ([Condition::STATUS_ISSUE_STAR,Condition::STATUS_REPORT_STAR].include?(condition.category) && condition.user == User.current) || ([Condition::STATUS_ISSUE_SYSTEM,Condition::STATUS_REPORT_SYSTEM].include?(condition.category) && User.current.admin?)
  end
end
