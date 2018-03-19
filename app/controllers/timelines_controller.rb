class TimelinesController < ApplicationController
  layout 'admin'
  before_filter :find_project_by_project_id, :only => [:index, :create, :branch_points]

  def index
  end

  def edit

  end

  def create
    params[:timelines][:plans].each { |plan, timetype|
      create_timelines_params = timelines_params.dup
      create_timelines_params[:group_key] = create_timelines_params[:group_key] || timelines_params[:name]
      create_timelines_params[:time_display] = timetype
      create_timelines_params[:related_id] = plan.to_s.split('_').last.to_i

      @project.timelines << Timeline.new(create_timelines_params) if @project.timelines.find_by_name_and_related_id(create_timelines_params[:name], create_timelines_params[:related_id]).blank?
    } if params[:timelines][:plans]

    render :text => {:success => 1, :message => "创建成功!"}.to_json
  rescue => e
    render :text => {:success => 0, :message => e.to_s}.to_json
  end

  def branch_points
    rows = @project.timelines.select("plans.name plan_name,timelines.*").joins("inner join plans on plans.id = timelines.related_id").where(:name => params[:name])

    render :text => {:success => 1, :rows => rows}.to_json
  rescue => e
    render :text => {:success => 0, :message => e.to_s}.to_json
  end

  private
  def timelines_params
    params.require(:timelines).permit(:name, :container_id, :container_type, :group_key, :parent_id, :author_id, :plans)
  end
end
