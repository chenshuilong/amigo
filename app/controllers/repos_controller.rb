class ReposController < ApplicationController
  include ReposHelper
  include SortHelper
  helper :sort

  before_filter :require_login, only: [:index, :new, :create, :show, :edit, :update]
  before_action :find_repo, only: [:show, :edit, :update, :link, :unlink, :destroy]
  before_action :auth_user, only: [:edit, :destroy, :new, :create, :update]
  # before_action :authorize, only: [:link, :unlink]
  before_action :require_login

  accept_api_auth :create

  layout 'repo'

  # /repos
  # @param category
  def index
    sort_init 'id', 'desc'
    sort_update %w(id name description url created_at updated_at author_id)
    respond_to do |format|
      @category = params[:category]
      @url = params[:url]
      @limit = per_page_option
      format.html {
        scope = Repo.active
        scope = scope.where(:category => @category) if @category.present?
        scope = scope.where("url LIKE '%#{@url}%'") if @url.present?
        @count = scope.count
        @pages = Paginator.new @count, @limit, params['page']
        @offset ||= @pages.offset
        @repos = scope.limit(@limit).offset(@offset).to_a
      }
      format.json {
        @project = Project.find_by(:id => params[:project_id])
        scope = Repo.active.select('id, url')
        scope = scope.where(:category => @category) if @category.present?
        scope = scope.where("LOCATE('#{params[:name]}', url) > 0") if params[:name].present?

        if @category.to_i == Repo::REPO_CATEGORY[:production] && @project.present?
          if @project.parent
            scope = scope.where("url LIKE '%#{@project.identifier}%' OR url LIKE '%#{@project.parent.identifier}%'")
            scope = scope.order(:url => :asc)
          else
            scope = scope.where("url LIKE '%#{@project.identifier}%'")
            scope = scope.order(:url => :asc)
          end
        elsif @category.to_i == Repo::REPO_CATEGORY[:package] && @project.present?
          scope = scope.where("url LIKE '%#{@project.identifier.to(6)}%'") if @project.category.to_i != Project::PROJECT_CATEGORY["终端项目"].to_i
          scope = scope.order("case when url LIKE '%#{@project.identifier.to(7)}%' then 1
                                    when url LIKE '%#{@project.identifier.to(6)}%' then 2
                                    when url LIKE '%#{@project.identifier.to(5)}%' then 3
                                    when url LIKE '%#{@project.identifier.to(4)}%' then 4
                                    else 5 end")
        end

        page = params[:page] || 1
        offset = (page.to_i - 1) * @limit
        @repos = scope.uniq.limit(@limit).offset(offset).to_a
        render :json => @repos, :status => :ok
      }
    end
  end

  def new
    @repo = Repo.new
  end

  def create
    @repo = Repo.new(repo_params)
    @repo.url_type = 1
    @repo.author ||= User.current

    if @repo.save
      respond_to do |format|
        format.html { redirect_to @repo }
        format.api { render :text => "Saved!", :status => :ok }
      end
    else
      respond_to do |format|
        format.html { render 'new' }
        format.api { render_error }
      end
    end
  end

  def show
    auth @repo
  end

  def edit
  end

  def update
    @repo.update_attributes(repo_params)
    if @repo.save
      redirect_to @repo
    else
      render 'edit'
    end
  end

  def link
    project_id = params[:project_id]
    if @repo.present? && !@repo.projects.pluck(:id).include?(project_id.to_i)
      link_status = Repo.link(project_id, @repo.id)
    else
      link_status = false
    end
    respond_to do |format|
      format.json {
        if link_status
          render :json => @repo.id, :status => :ok
        else
          head :forbidden
        end
      }
    end
  end

  def unlink
    project_id = params['project_id']
    freezed = Repo.get_freeze_status_by_repo_id(project_id, @repo.id).first["freezed"].to_i == 1
    Repo.unlink(project_id, @repo.id) unless freezed
    respond_to do |format|
      format.json {
        if freezed
          head :forbidden
        else
          render :json => @repo.id, :status => :ok
        end
      }
    end
  end

  def freeze
    project_id    = params['project_id']
    repo_id       = params['repo_id']
    freeze_status = params[:freezed]
    Repo.freeze(project_id, repo_id, freeze_status)
    respond_to do |format|
      format.json {
        render :json => repo_id, :status => :ok
      }
    end
  end

  def getlink
    project_id = params['project_id']
    projects_repos = Repo.get_link(project_id)
    projects_repos.each do |r|
      puts r
      r['category_name'] = Repo.get_category_name(r['category'])
      r['author_name'] = User.find(r['author_id']).name
    end
    respond_to do |format|
      format.json {
        render :json => projects_repos, :status => :ok
      }
    end
  end

  def destroy
    @repo.destroy
    redirect_to repos_path
  end

  def compile_machine_status
    auth :repo
    @jenkins = Api::Jenkins.new
    begin
      @labels = @jenkins.labels(:node => true)
    rescue
      logger.info('Cannot access Jenkins api sever!')
    end
  end

private
  def repo_params
    params.require(:repo).permit(:description, :url, :category, :url_type)
  end

  def find_repo
    @repo = Repo.find_by(:id => params[:id] || params[:repo_id])
  end

  def auth_user
    unless User.current.is_scm?
      render_403
      return false
    end
  end
end
