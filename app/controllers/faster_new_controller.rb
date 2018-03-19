class FasterNewController < ApplicationController
  MENU_INFO = {project: [{name: " 新建项目", permission: :add_project}],
               production: [{name: " 新建产品", permission: :add_project}],
               issue: [{name: " 新建问题", permission: :add_issues}],
               version: [{name: " 新建项目版本", permission: :manage_versions, type: "project"},
                         {name: " 新建应用版本", permission: :manage_versions, type: "production"}],
               version_release: [{name: " 新建发布", permission: :release_versions}],
               personal_task: [{name: " 新建普通任务"}]}.freeze

	before_filter :find_project, only:[:issue]
  before_filter :build_new_issue_from_params, :only => [:issue]
  before_filter :find_objects, only: [:version]
  before_filter :require_login

  helper :projects
  helper :issues
  helper :versions
  helper :version_releases
  helper :custom_fields
  helper :attachments

  layout 'faster_new'

  def project
    @issue_custom_fields = IssueCustomField.sorted.to_a
    @trackers = Tracker.sorted.to_a
    @project = Project.new
    @project.safe_attributes = params[:project]
    @project.category ||= 1
  end

  def issue
    @default_values = User.current.default_values.issue
  end

  def version
    if params[:default_value_id].present?
      @default_value = DefaultValue.find(params[:default_value_id])
      @json = JSON.parse(@default_value.json)
      @project = Project.find(@json["version[project_identifier]"])
      @version = @project.versions.build
      @version.name                 = @json["version[name]"]
      @version.spec_id              = @json["version[spec_id]"]
      @version.priority             = @json["version[priority]"]
      @version.ota_whole_compile    = @json["version[ota_whole_compile]"]
      @version.ota_increase_compile = @json["version[ota_increase_compile]"]
      @version.description          = @json["version[description]"]
      @version.repo_one_id          = @json["version[repo_one_id]"]
      @version.repo_two_id          = @json["version[repo_two_id]"]
      @version.signature            = @json["version[signature]"]
      @version.compile_due_on       = @json["version[compile_due_on]"]
      @version.mail_receivers       = @json["version[mail_receivers][]"]

      project_type = @project.production_type? ? "production" : "project"
      find_objects(project_type)
    else
      @project = params[:project_id].present? ? Project.find(params[:project_id]) : @projects.first
      @version = @project.versions.build
      @version.name = @project.default_version_name if @version.name.blank?
      @version.priority ||= Version::VERSION_PRIORITY[:normal]
      @version.auto_test ||= false
      @version.ota_whole_compile ||= true
      @version.ota_increase_compile ||= false
      @version.safe_attributes = params[:version]
    end

    @default_values = User.current.default_values.version
  end

  def version_release
    @release = VersionRelease.new
    @release.attributes = release_params if params[:version_release].present?
    @release.category ||= VersionRelease.consts[:category][:complete]
  end

  def production
    @issue_custom_fields = IssueCustomField.sorted.to_a
    @trackers = Tracker.sorted.to_a
    @project = Project.new
    @project.category = 4
    @project.safe_attributes = params[:project]
  end

  def index
    respond_to { |format| format.js }
  end

  def personal_task
   @task = Task.new(container_type: "PersonalTask", status: 1)
  end

  private

  def build_new_issue_from_params
    @issue = Issue.new
    if params[:copy_from]
      begin
        @issue.init_journal(User.current)
        @copy_from = Issue.visible.find(params[:copy_from])
        unless User.current.allowed_to?(:copy_issues, @copy_from.project)
          raise ::Unauthorized
        end
        @link_copy = link_copy?(params[:link_copy]) || request.get?
        @copy_attachments = params[:copy_attachments].present? || request.get?
        @copy_subtasks = params[:copy_subtasks].present? || request.get?
        @issue.copy_from(@copy_from, :attachments => @copy_attachments, :subtasks => @copy_subtasks, :link => @link_copy)
        @issue.parent_issue_id = @copy_from.parent_id
      rescue ActiveRecord::RecordNotFound
        render_404
        return
      end
    end

    @issue.project = @project
    if request.get?
      @issue.project ||= @issue.allowed_target_projects.first
    end

    # version_fullname rewrite project when auto submit
    if params[:auto_submit]
      fullname = params[:issue][:version_fullname]
      version = Version.find_by_fullname(fullname)
      version ||= Project.where(:identifier => fullname.gsub(/\d+_.+\z/, '')).first
      @issue.project = version.try(:project)

      if @issue.project.nil?
        render_error :status => 500, :message => 'Project not found'
      end
    end

    @issue.author ||= User.current
    @issue.start_date ||= User.current.today if Setting.default_issue_start_date_to_creation_date?

    attrs = (params[:issue] || {}).deep_dup
    if action_name == 'new' && params[:was_default_status] == attrs[:status_id]
      attrs.delete(:status_id)
    end
    if action_name == 'new' && params[:form_update_triggered_by] == 'issue_project_id'
      # Discard submitted version when changing the project on the issue form
      # so we can use the default version for the new project
      attrs.delete(:fixed_version_id)
    end
    @issue.safe_attributes = attrs

    if @issue.project
      @issue.tracker ||= @issue.allowed_target_trackers.first
      if @issue.tracker.nil?
        if @issue.project.trackers.any?
          # None of the project trackers is allowed to the user
          render_error :message => l(:error_no_tracker_allowed_for_new_issue_in_project), :status => 403
        else
          # Project has no trackers
          render_error l(:error_no_tracker_in_project)
        end
        return false
      end
      if @issue.status.nil?
        render_error l(:error_no_default_issue_status)
        return false
      end
    end

    @priorities = IssuePriority.active
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
  end

  def find_objects(project_type=nil)
    project_type ||= params[:project_type]
    @projects = project_type == "project" ? Project.default.where(ownership: 1) : Project.where(ownership: 1, category: 4, production_type: [1, 2, 3])
  end

  def find_project
    return true unless params[:id]
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
