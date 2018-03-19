class PatchesController < ApplicationController
  before_filter :require_login
  before_action :find_patch, only: [:infos, :jenkins_url]
  # before_action :authorize, :except => [:index, :infos, :new, :create, :show, :generate_patchno, :files]

  accept_api_auth :infos

  def index
    auth :patch
    @author = params[:author]
    @status = params[:status]
    @created_at_start = params[:created_at_start]
    @created_at_end = (Date.parse(params[:created_at_end]) + 1).to_s if params[:created_at_end].present?
    @actual_due_at_start = params[:actual_due_at_start]
    @actual_due_at_end = (Date.parse(params[:actual_due_at_end]) + 1).to_s if params[:actual_due_at_end].present?


    scope = Patch.includes(:author)
    scope = scope.where(author_id: @author) if @author.present?
    scope = scope.where(status: @status) if @status.present?
    scope = scope.where(:created_at => @created_at_start..@created_at_end) if @created_at_start.present?
    scope = scope.where(:actual_due_at => @actual_due_at_start..@actual_due_at_end) if @actual_due_at_start.present?

    @limit = per_page_option
    @count = scope.count
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @patches = scope.limit(@limit).offset(@offset).reorder("created_at desc").to_a
  end

  def new
    auth :patch
    @patch_type = params[:patch].try(:[], :patch_type) || 1
    @patch = Patch.new
    @patch.patch_type = @patch_type
    @patch.patch_no = Patch.generate_patchno(@patch.patch_type.to_i)
    if params[:format].present? && params[:format] == 'js'
      @patch.notes = patch_params[:notes]                           if patch_params[:notes].present?
      if (init_command = patch_params[:init_command]).present?
        @manifest_url = init_command[:manifest_url] if init_command.try(:[], :manifest_url)
        @manifest_branch = init_command[:manifest_branch] if init_command.try(:[], :manifest_branch)
        @manifest_xml = init_command[:manifest_xml] if init_command.try(:[], :manifest_xml)
        @repo_url = init_command[:repo_url] if init_command.try(:[], :repo_url)
      end

      @patch.due_at = patch_params[:due_at]  if patch_params[:due_at].present?
      @patch.object_ids = patch_params[:object_ids] if patch_params[:object_ids].present?
      @patch.proprietary_tag = patch_params[:proprietary_tag] if patch_params[:proprietary_tag].present?
      render 'new'
    end
  end

  def create
    auth :patch
    @specs = Spec.where(id: patch_params[:object_ids])
    @patch = Patch.new(patch_params)
    @patch.status = 'doing'
    @patch.patch_no = Patch.generate_patchno(@patch.patch_type.to_i)
    object_names = {}
    if @specs.present?
      @specs.collect{|a| object_names[a.id] = "#{a.project.identifier}#{a.name}"}
    end
    @patch.object_names = object_names
    @patch.author_id = User.current.id

    respond_to do |format|
      unfinishes = Patch.where(patch_type: @patch.patch_type, status: "doing")
      if unfinishes.present?
        format.html do
          flash[:error] = "#{unfinishes.last.patch_no} 合入任务正在执行中，请在任务完成后创建任务！"
          redirect_back_or_default patches_path
        end
      elsif @patch.save
        @patch.do_jenkins_job("task_001")
        format.html do
          flash[:notice] = l(:notice_successful_create)
          redirect_back_or_default patches_path
        end
      else
        if (init_command = patch_params[:init_command]).present?
          @manifest_url = init_command[:manifest_url] if init_command.try(:[], :manifest_url)
          @manifest_branch = init_command[:manifest_branch] if init_command.try(:[], :manifest_branch)
          @manifest_xml = init_command[:manifest_xml] if init_command.try(:[], :manifest_xml)
          @repo_url = init_command[:repo_url] if init_command.try(:[], :repo_url)
        end
        format.html { render :action => 'new' }
      end
    end
  end

  def show
    auth :patch
    @patch = Patch.find(params[:id])
    @tab = params[:tab] || "history"
    case @tab
    when "history"
      @records = @patch.alter_records.reorder("created_at desc")
    when "libraries"
      @libraries = @patch.libraries.group("libraries.name, libraries.path").includes(:user)
    when "precompile"
      @precompiles = @patch.patch_versions.where(category: "precompile")
    when "postcompile"
      @postcompiles = @patch.patch_versions.where(category: "postcompile")
    when "library_files"
      @library_files = LibraryFile.libraries(@patch.id)
    when "failed_libraries"
      @faileds = @patch.libraries.where.not(status: %(initial)).group("libraries.name, libraries.path").includes(:user)
    end
    
    render 'show' if params[:type].present? && params[:type] == 'js'
  end

  def generate_patchno
    @patch_no = Patch.generate_patchno(params[:patch_type].to_i)
    respond_to do |format|
      format.js
    end
  end

  def infos
    if params[:token].in? [Token::SCM_TOKEN]
      has = -> (key) { params.has_key?(key) }
      if @patch.status == "doing"
        if has.(:result)
          saved = @patch.do_closed(params)
        elsif has.(:operation)
          saved = @patch.do_rewrite_jenkins(params)
        else
          saved = true
        end
      else
        saved = false
      end


      respond_to do |format|
        if saved
          format.api{ render :text => "Saved!", :status => :ok }
        else
          format.api{ render_error }
        end
      end
    else
      render_error :status => 422, :message => "Invalid authenticity token."
    end
  end

  def files
    @lib = Library.find_by(id: params[:library_id])
    @patch = @lib.container
    @commons = @patch.libraries.where(name: @lib.name)
    @files = []
    @commons.each do |common|
      next unless common.files.present?
      @files = @files + JSON.parse(common.files)
    end
    @files = @files

    respond_to do |format|
      format.js
    end
  end

  def jenkins_url
    if params[:token].in? [Token::SCM_TOKEN]
      has = -> (key) { params.has_key?(key) }
      if has.(:jenkins_url)
        saved = @patch.update_jenkins_url(params)
      else
        saved = true
      end

      respond_to do |format|
        if saved
          format.api{ render :text => "Saved!", :status => :ok }
        else
          format.api{ render_error }
        end
      end
    else
      render_error :status => 422, :message => "Invalid authenticity token."
    end
  end

  def search_spec
    respond_to do |format|
      @name = params[:name]
      format.js {
        scope = Spec.joins(:project).where(projects: {category: [1,2,3]}, deleted: false)
                      .where.not("projects.ownership = 2 AND projects.identifier LIKE '%_ODM'")
                      .select("concat(projects.identifier, specs.name) as full_name, specs.id")
                      .where("projects.identifier LIKE '%#{@name}%' OR specs.name LIKE '%#{@name}%' OR concat(projects.identifier, specs.name) LIKE '%#{@name}%'")
                      .reorder("full_name asc")

        page     = params[:page] || 1
        limit    = 20
        offset   = (page.to_i - 1) * limit
        specs = scope.limit(limit).offset(offset)
        render :json => specs.map{|s| {:id => s.id, :name => s.full_name}}
      }
    end
  end

  def conflict_files
    @lib = Library.find_by(id: params[:lib_id])
    @files = @lib.library_files.includes(:user)
    respond_to do |format|
      format.js
    end
  end

  private
  def patch_params
    final = params.require(:patch).permit(:patch_type, :notes, :due_at, :proprietary_tag, :spec_id, :init_command => [:manifest_url, :manifest_branch, :manifest_xml, :repo_url])
    if params["patch"]["object_ids"].present?
      final[:object_ids] = params["patch"]["object_ids"].is_a?(Array) ? params["patch"]["object_ids"] : params["patch"]["object_ids"].split(",")
    end
    return final
  end

  def find_patch
    @patch = Patch.find(params[:id])
  end
end
