class RepoRequestsController < ApplicationController
  helper :issues
  layout 'repo'

  before_filter :require_login
  before_action :find_repo_request, only: [:edit, :update, :show, :abandon]
  before_action :find_all_by_category, only: [:index]
  before_action :check_judge, only: [:create, :update]

  def index 
    authorized_view("apply", params[:category])
    @limit = per_page_option
    @count = @repo_requests.count
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @repo_requests = @repo_requests.limit(@limit).offset(@offset).reorder("created_at desc").to_a
  end

  def new
    authorized_only("apply", params[:category])
    category = RepoRequest::REPO_REQUEST_CATEGORY[params[:category].to_sym]
    @repo_request = RepoRequest.new(category: category, status: "submitted")
    @repo_request.production_type = params[:production_type] || "apk" if params[:category] == "production_repo"
    @repo_request.production_type = params[:production_type] || "china" if params[:category] == "project_branch"
  end

  def create
    @repo_request = RepoRequest.new(repo_request_params)
    @repo_request.status = "agreed" if repo_request_params[:use].to_i == 5
    @repo_request.author_id = User.current.id
    respond_to do |format|
      if @repo_request.save
        @repo_request.generate_notes_alter_record(params[:repo_request][:notes]) if params[:repo_request][:notes].present?
        format.html do
          flash[:notice] = l(:notice_successful_create)
          redirect_back_or_default repo_request_path(@repo_request)
        end
      else
        format.html { render :action => 'new' }
      end
    end
  end

  def edit
    authorized_edit("apply", @repo_request)
    @repo_request.production_type = params[:production_type] if params[:production_type].present?
    @notes = @repo_request.visible_alter_records
  end

  def update
    @repo_request.status = "confirmed" if @repo_request.agreed?

    respond_to do |format|
      if @repo_request.update(repo_request_params)
        @repo_request.generate_notes_alter_record(params[:repo_request][:notes]) if params[:repo_request][:notes].present?
        format.html do
          flash[:notice] = l(:notice_successful_update)
          redirect_back_or_default repo_request_path(@repo_request)
        end
      else          
        @repo_request.status = @repo_request.status_was if repo_request_params[:notes].blank?
        format.html { render :action => 'edit' }
      end
    end
  end

  def show
    category = RepoRequest::REPO_REQUEST_CATEGORY.key(@repo_request.category).to_s
    authorized_view("apply", category)
    @notes = @repo_request.visible_alter_records
  end
  
  def search_projects
    name = params[:name]
    page = params[:page] || 1
    limit = 20
    offset = (page.to_i - 1) * limit
    case params[:category].to_i
    when 1
      which = Project.active.default
      which = which.where(ownership: params[:production_type] == "china" ? 1 : 2)  if params[:production_type].present?
    when 2
      which = Project.active.categories("other").where(production_type: [1, 2, 3])
    when 3
      pd_type = params[:production_type] == "apk" ? 1 : 8
      which = Project.active.categories("other").where(production_type: pd_type)
    end
    scope = which.where("lower(name) like '%#{params[:name]}%'")
    projects = scope.limit(limit).offset(offset)
    @projects = projects.map{|p| {:id => p.id, :name => p.name}}
    render :json => @projects.to_json
  end

  def search_versions
    if params[:project_id].present?
      name = params[:name]
      page = params[:page] || 1
      limit = 20
      offset = (page.to_i - 1) * limit
      @project = Project.find_by(id: params[:project_id])

      scope = @project.hm_versions.compile_status(6).joins(:spec)
                  .select("concat(specs.name, '_', versions.name) as name, versions.id")
                  .where("versions.name like '%#{params[:name]}%' OR specs.name like '%#{params[:name]}%' OR concat(specs.name, '_', versions.name) like '%#{params[:name]}%'")
                  .reorder("name asc")

      versions = scope.limit(limit).offset(offset)
      @versions = versions.map{|p| {:id => p.id, :name => p.name}}
      render :json => @versions.to_json
    else
      render :json => {}.to_json
    end
  end

  def issue_to_approve_merges
    @project = Project.find(params[:project_id])
  
    render :json => {:success => 1, :rows => @project.repo_requests.success_requests}.to_json
  rescue => e
    render :json => {:success => 0, :message => e.to_s}.to_json
  end

  def abandon
    @repo_request.status = "abandoned"
    @repo_request.save
    redirect_back_or_default repo_requests_index_path(category: "project_branch")
  end

  private
  def repo_request_params
    require_params = params.require(:repo_request).permit(:server_ip, :android_repo, :package_repo, :project_id, :notes, :version_id, :branch, :tag_number, :notes,
    	                              :production_type, :repo_name, :status, :category, :use, :write_users => [], :read_users => [], :submit_users => [])
    require_params[:branch]       = 'branch_' + require_params[:branch] if require_params[:branch].present?
    require_params[:project_id]   = "" if require_params[:category] == "3" && (require_params[:production_type] == "other")
    require_params[:repo_name]    = "" if require_params[:category] == "3" && (require_params[:production_type] != "other")
    require_params[:write_users]  = require_params[:write_users].delete_if{|u| u.blank?} if require_params[:write_users].present?
    require_params[:read_users]   = require_params[:read_users].delete_if{|u| u.blank?}   if require_params[:read_users].present?
    require_params[:submit_users] = require_params[:submit_users].delete_if{|u| u.blank?} if require_params[:submit_users].present?
    require_params[:status]       = "agreed" if require_params[:category].to_i == 1 && require_params[:use].to_i == 5
    # require_params[:notes]        = ""       if require_params[:category].to_i == 1
    return require_params
  end

  def find_repo_request
    @repo_request = RepoRequest.find(params[:id])
  end

  def find_all_by_category
    @repo_requests = RepoRequest.where(category: RepoRequest::REPO_REQUEST_CATEGORY[params[:category].to_sym]).includes(:author, :project, :version)
  end

  def authorized_only(type, category)
    user = User.current
    allowed = user.can_do?(type, category)
    if allowed
      true
    else
      render_403 :message => :notice_not_authorized_archived_project
    end
  end

  def authorized_edit(type, obj)
    allowed = obj.can_edit?

    if allowed
      true
    else
      render_403 :message => :notice_not_authorized_archived_project
    end
  end

  def authorized_view(type, category)
    user = User.current
    allowed = user.can_do?(type, category)
    allowed = allowed || user.resourcing_permission?("view_#{category}".to_sym)
    if allowed
      true
    else
      render_403 :message => :notice_not_authorized_archived_project
    end
  end

  def check_judge
    if repo_request_params[:status].present? && %w(submitted agreed).exclude?(repo_request_params[:status])
      authorized_only("judge", RepoRequest::REPO_REQUEST_CATEGORY.key(repo_request_params[:category].to_i).to_s)
    end
    if repo_request_params[:category] == "2" && repo_request_params[:status] == "submitted"
      authorized_only("apply", RepoRequest::REPO_REQUEST_CATEGORY.key(repo_request_params[:category].to_i).to_s)
    end
  end
end
