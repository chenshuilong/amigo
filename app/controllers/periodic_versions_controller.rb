class PeriodicVersionsController < ApplicationController

  model_object VersionPeriodicTask
  helper :sort
  include SortHelper

  before_action :check_version_task_auth, :only => [:new, :create, :edit, :update, :close]
  before_action :check_version_rule_auth, :only => [:new_version_name_rule, :edit_version_name_rule]

  def index
    auth :periodic_version
    sort_init 'status', 'asc'
    sort_update %w(name status time running_count author_id last_running_on created_at)
    respond_to do |format|
      format.html {
        @limit  = per_page_option
        @name   = params[:name]
        @status = params[:status]
        @author = params[:author]
        @created_at_start = params[:created_at_start]
        @created_at_end = (Date.parse(params[:created_at_end]) + 1).to_s if params[:created_at_end].present?

        scope = VersionPeriodicTask.all
        scope = scope.where("name LIKE '%#{@name}%'") if @name.present?
        scope = scope.where(:status => @status) if @status.present?
        scope = scope.where(:project_id => @project_id) if @project_id.present?
        scope = scope.where(:author_id => @author) if @author.present?
        scope = scope.where(:created_at => @created_at_start..@created_at_end) if @created_at_start.present?

        @task_count = scope.count
        @task_pages = Paginator.new @task_count, @limit, params['page']
        @offset ||= @task_pages.offset
        @tasks =  scope.order(sort_clause).limit(@limit).offset(@offset).to_a
      }
    end
  end

  def new
    @task = VersionPeriodicTask.new
    @projects = Project.where(:category => [1,2,3])
    @rules = VersionNameRule.all
    if params[:version].present?
      @version = VersionPeriodicTask::Version.new(params[:version])
      @project = @version.project
    else
      @project = @projects.first
      @version = @task.version
    end

    respond_to do |format|
      format.js
      format.html { render :action => 'new', :layout => !request.xhr? }
    end
  end

  def create
    @task = VersionPeriodicTask.new(task_params)
    @task.author = User.current
    @task.status = @task.class.consts[:status][:enable]
    @task.form_data = params[:version]
    @task.weekday = params[:task][:weekday].join
    if @task.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to periodic_versions_path
    else
      @projects = Project.where(:category => [1,2,3])
      @rules = VersionNameRule.all
      @version = @task.version
      @project = @version.project
      render :action => 'new'
    end
  end

  def show
    auth :periodic_version
    @task = VersionPeriodicTask.find(params[:id])
    @version = @task.version
  end

  def edit
    @task = VersionPeriodicTask.find(params[:id])
    @version = @task.version
    @project = @version.project
    @projects = Project.where(:category => [1,2,3])
    @rules = VersionNameRule.all
  end

  def update
    @task = VersionPeriodicTask.find(params[:id])
    @task.update_attributes(task_params)
    @task.form_data = params[:version]
    @task.weekday = params[:task][:weekday].join
    if @task.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to periodic_version_path(@task)
    end
  end

  def close
    @task = VersionPeriodicTask.find(params[:id])
    if @task.close
      render :js => "location.reload()"
    end
  end

  def version_name_rules
    auth :periodic_version
    @rules = VersionNameRule.all
  end

  def new_version_name_rule
    if request.get?
      @rule = VersionNameRule.new
    else
      @rule = VersionNameRule.new(rule_params)
      @rule.author = User.current
      if @rule.save
        flash[:notice] = l(:notice_successful_create)
        redirect_to rules_periodic_versions_path
      end
    end
  end

  def edit_version_name_rule
    @rule = VersionNameRule.find(params[:id])
    if request.post?
      @rule.update_attributes(rule_params)
      @rule.author = User.current
      if @rule.save
        flash[:notice] = l(:notice_successful_update)
        redirect_to rules_periodic_versions_path
      end
    end
  end

  private

  def rule_params
    params.require(:version_name_rule).permit(:name, :description, :range, :android_platform)
  end

  def task_params
    params.require(:task).permit(:name, :description, :time, :weekday)
  end

  def check_version_task_auth
    render_403 unless VersionPeriodicTask.permit?
  end

  def check_version_rule_auth
    render_403 unless VersionNameRule.permit?
  end

end


