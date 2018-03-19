class IssueToMergesController < ApplicationController
  before_filter :find_project_by_project_id, :only => [:index]
  before_action :require_login

  helper :sort
  include SortHelper
  menu_item :issues

  def index
    sort_init 'id', 'desc'
    sort_update %w(id issue_type issue_id commit_id branche_ids related_issue_ids related_apks tester_advice dept_result project_result master_version_id branch_version_ids)
    respond_to do |format|
      format.html {
        @status = IssueToMergeTask::ASSIGNED_STATUS.to_a.map { |status| {:name => status[1][1], :id => status[1][0]} }
        @repos = @project.repo_requests.success_requests
        @limit = per_page_option

        scope = IssueToApproveMerge.merges
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
end
