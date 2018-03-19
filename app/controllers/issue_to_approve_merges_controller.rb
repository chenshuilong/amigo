class IssueToApproveMergesController < ApplicationController
  layout 'admin'
  before_filter :find_project_by_project_id, :only => [:index]

  helper :sort
  include SortHelper

  def index
    sort_init 'id', 'desc'
    sort_update %w(id issue_type issue_id commit_id branche_ids related_issue_ids related_apks tester_advice dept_result project_result master_version_id branch_version_ids)
    respond_to do |format|
      format.html {
        @menuid = params[:menuid].to_s
        # @status = (@menuid << "_task").camelize.constantize::ASSIGNED_STATUS.to_a.map { |status| {:name => status[1][1], :id => status[1][0]} }
        @status = (@menuid.include?('approve') ? IssueToApproveTask::ASSIGNED_STATUS : IssueToMergeTask::ASSIGNED_STATUS).to_a.map { |status| {:name => status[1][1], :id => status[1][0]} }
        @repos = @project.repo_requests.success_requests
        @limit = per_page_option

        scope = IssueToApproveMerge.all
        scope = scope.where(:issue_type => @menuid.camelize)
        scope = scope.where(:issue_id => @project.issues.map { |issue| issue.id}) if @project.present?

        @issue_count = scope.count
        @issue_pages = Paginator.new @issue_count, @limit, params['page']
        @offset ||= @issue_pages.offset
        @issues =  scope.order(sort_clause).limit(@limit).offset(@offset).to_a
      }
      format.api {
        render_api_ok
      }
    end
  end

  def edit
    issue = IssueToApproveMerge.find(params[:id])
    issue.update(issues_params << {:repo_request_ids => issue_to_merge_repo_requests.to_json}) if issue.present?

    render :text => {:success => 1, :message => "操作成功!"}.to_json
  rescue => e
    render :text => {:success => 0, :message => e.to_s, :row => []}.to_json
  end

  def send_task
    approve = IssueToApproveMerge.find(issues_params[:id])
    raise "问题不存在！" if approve.blank?

    approve.update(issues_params)
    status = params[:issues][:status_id].to_i
    if status == 1
      Task.create({:container_type => "IssueToApprove", :container_id => approve.id, :name => "收到来自问题##{approve.issue_id}的评审必合",
                   :assigned_to_id => approve.issue.assigned_to_id, :author_id => User.current.id, :status => status,
                   :start_date => Time.now.to_s(:db)}) if Task.find_by_container_type_and_container_id("IssueToApprove", approve.id).blank?
    end

    render :text => {:success => 1, :message => "操作成功!"}.to_json
  rescue => e
    render :text => {:success => 0, :message => e.to_s, :row => []}.to_json
  end

  private

  def issues_params
    params.require(:issues).permit(:id, :commit_id, :branche_ids, :related_issue_ids, :related_apks, :tester_advice, :dept_result, :project_result, :master_version_id, :branch_version_ids, :notes, :reason, :requirement)
  end

  def issue_to_merge_repo_requests
    repos = []
    params[:repos].each { |k, v|
      repos << {:repo_request_id => k.to_s.split('_')[1], :result => ""} if v.to_i == 1
    }
    repos
  end
end
