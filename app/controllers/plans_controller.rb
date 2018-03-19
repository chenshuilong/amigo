class PlansController < ApplicationController

  before_filter :find_project_by_project_id, :only => [:index, :edit, :lock, :quick_sort]
  before_action :require_login

  def index
    respond_to do |format|
      format.html {
        @menuid             = params[:menuid].to_s
        @timelines          = Timeline.choice
        varite_by_menu
      }
      format.api {
        render_api_ok
      }
    end
  end

  def create

  end

  def edit
    if params[:id].to_i > 0
      plan = Plan.find(params[:id])
      raise "任务已经在流转，无法修改!" if plan.tasks.present? && plan.tasks.first.status && plan.tasks.first.status != Task::TASK_STATUS[:submitted][0]

      plan.update(handle_plan_params)
    else
      plan = Plan.create(handle_plan_params)
    end

    # generate alter records and details
    if string_to_boolean(plan_params[:recordable])
      plan.alter_records << plan.init_alter_for(current_user)
    end

    row = @project.plans.select(plans_select_fields).joins(plans_joins_tables).where("plans.name = '#{plan_params[:name]}' and plans.id = #{plan.id}")
    render :text => {:success => 1, :message => "操作成功!", :row => row}.to_json
  rescue => e
    render :text => {:success => 0, :message => e.to_s, :row => []}.to_json
  end

  def lock
    @project.plan_locked = true
    @project.save

    respond_to do |format|
      format.api {
        render_api_ok
      }
    end
  end

  def destroy
    plan = Plan.find(params[:id])
    if plan.present?
      if plan.parent_id.present?
        plan.children.delete_all
      end
      plan.destroy
    end

    render :text => {:success => 1, :message => "操作成功!"}.to_json
  rescue => e
    render :text => {:success => 0, :message => e.to_s}.to_json
  end

  def get_data
    @rows = Plan.limit(params[:pagesize]).offset((params[:pagenum].to_i + 1) * params[:pagesize].to_i)

    render :text => {:data => @rows}.to_json
  rescue => e
    render :text => {:data => []}.to_json
  end

  def send_task
    plan = Plan.find(params[:id])
    raise "项目计划不存在" if plan.blank?
    raise "没有发送的责任人" if plan.assigned_to_id.blank?
    raise "计划开始时间或者计划完成时间不能为空" if plan.plan_due_date.blank? || plan.plan_start_date.blank?

    Task.transaction do
      plan.tasks << Task.new({:name => plan.name, :assigned_to_id => plan.assigned_to_id,
                              :start_date => Time.now.to_s(:db), :author_id => User.current.id}) if plan.tasks.blank?
    end

    render :text => {:success => 1, :message => "任务已经成功发送给#{plan.assigned_to.firstname}!"}.to_json
  rescue => e
    render :text => {:success => 0, :message => e.to_s}.to_json
  end

  def quick_sort
    @project.plans.order(:id).each do |plan|
      plan.position = @project.plans.order(:id).index(plan) + 1
      plan.save
    end

    render :js => "layer.alert('插入成功！');// refreshPage();"
  rescue => e
    render :js => "layer.alert('#{e.to_s}');"
  end

  private
  def plan_params
    params.require(:plans).permit(:id, :project_id, :parent, :parent_id, :plan_start_date, :plan_due_date, :assigned_to_id, :check_user_id, :description, :name, :author_id, :status, :recordable, :position)
  end

  def handle_plan_params
    plans                   = plan_params.dup
    plans["parent_id"]      = Plan.find_by_name(plans[:parent]) ? Plan.find_by_name(plans[:parent]).id : nil if plans[:parent]
    plans["parent_id"]      = plans[:parent_id] if plans[:parent_id].present?
    plans["assigned_to_id"] = @project.users.find_by_firstname(plans[:assigned_to_id]).id if plans[:assigned_to_id].present?
    plans["check_user_id"]  = @project.users.find_by_firstname(plans[:check_user_id]).id if plans[:check_user_id].present?

    plans.delete "parent"
    plans.delete "status"
    plans.delete "recordable"

    plans
  end

  def plans_select_fields
    "plans.*,author.firstname author,assigned.firstname assigned,checker.firstname checker,tasks.start_date task_start_date,tasks.due_date task_due_date,tasks.status status_id,#{Task.convert_status}"
  end

  def plans_joins_tables
    "
      left join tasks on tasks.container_id = plans.id and tasks.container_type = 'Plan'
      left join users author on author.id = plans.author_id
      left join users assigned on assigned.id = plans.assigned_to_id
      left join users checker on checker.id = plans.check_user_id
    "
  end

  def varite_by_menu
    case @menuid
      when "wbs"
        @plans              = @project.plans.sorted.select(plans_select_fields).joins(plans_joins_tables)
        @project_id         = @project.identifier
        @status             = {:data => Task::TASK_STATUS.to_a.map { |status| {:name => status[1][1], :id => status[1][0]} }}.to_json
        @locked             = @project.plan_locked?
      when "key_point"
        @lines              = @project.timelines.select("timelines.id,timelines.related_id,timelines.name line_name,plans.name plan_name,timelines.parent_id,timelines.group_key,
          case when timelines.time_display = 1 then plans.plan_start_date
               when timelines.time_display = 2 then plans.plan_due_date
               when timelines.time_display = 3 then plans.created_at end plan_date").
            joins("inner join plans on plans.id = timelines.related_id").group_by(&:group_key)
        @x_distance = (params[:x_distance] || 10).to_i
        @y_distance = (params[:y_distance] || 100).to_i
      when "alter_record"
        @records            = @project.plans.first.alter_records
    end
  end
end
