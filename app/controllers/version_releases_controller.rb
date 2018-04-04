class VersionReleasesController < ApplicationController
  model_object VersionRelease
  before_action :find_model_object, :only => [:show, :edit]
  before_action :find_project_from_params, :only => [:create, :show, :version_lists, :rerelease, :update, :edit]
  before_action :authorize, :only => [:show, :create, :rerelease, :edit]
  before_filter :authorize_global, :only => [:new]

  accept_api_auth :create

  helper :sort
  helper :attachments
  include SortHelper

  def index
    auth :version_release if request.formats[0].symbol.to_s == "html"
    sort_init 'id', 'desc'
    sort_update %w(id category version_id author_id status failed_count tested_mobile version_applicable_to created_at test_finished_on)
    respond_to do |format|
      format.html {
        @limit = per_page_option
        @category = params[:category]
        @tested_mobile = params[:tested_mobile]
        @status = params[:status]
        @failed_count = params[:failed_count]
        @just_adpted = params[:just_adpted]
        @project_id = params[:project_id]
        @author = params[:author] == "me" ? User.current.id : params[:author]
        @has_problem = params[:has_problem]
        @created_at_start = params[:created_at_start]
        @created_at_end = (Date.parse(params[:created_at_end]) + 1).to_s if params[:created_at_end].present?

        scope = $db.slave { VersionRelease.all }
        scope = $db.slave { scope.where("status in (#{@status.map { |sta| VersionRelease.statuses[sta] }.join(',')})") } if @status.present? && @status != [""]
        if @tested_mobile.present? && @tested_mobile != [""]
          tm_where = @tested_mobile.map { |tm| "tested_mobile = '#{tm}' or tested_mobile like '%,#{tm}' or tested_mobile like '#{tm},%' or tested_mobile like '%,#{tm},%'" }.join(' or ')
          scope = $db.slave { scope.where(tm_where) }
        end
        scope = $db.slave { scope.where(:project_id => @project_id) } if @project_id.present?
        scope = $db.slave { scope.where(:author_id => @author) } if @author.present?
        scope = $db.slave { scope.where(:category => @category) } if @category.present?
        scope = $db.slave { scope.where(:created_at => @created_at_start..@created_at_end) } if @created_at_start.present?
        scope = $db.slave { scope.where(:has_problem => @has_problem) } if @has_problem.present?

        if @failed_count.present?
          scope = @failed_count.to_i > 0 ? $db.slave { scope.where('failed_count > 0') } : $db.slave { scope.where(:failed_count => [nil, 0]) }
        end

        if @just_adpted.present?
          if @just_adpted == 'true'
            scope = $db.slave { scope.where(:category => 2, :parent_id => nil) }
          else
            scope = $db.slave { scope.where('category = 2 AND parent_id IS NOT NULL') }
          end
        end

        @release_count = scope.count
        @release_pages = Paginator.new @release_count, @limit, params['page']
        @offset ||= @release_pages.offset
        @releases = $db.slave { scope.order(sort_clause).limit(@limit).offset(@offset).to_a }
      }
      format.api {
        render_api_ok
      }
    end
  end


  def new
    @release = VersionRelease.new
    @release.attributes = release_params if params[:version_release].present?
    @release.category ||= VersionRelease.consts[:category][:complete]
    respond_to do |format|
      format.js
      format.html { render :action => 'new', :layout => !request.xhr? }
    end
  end

  def create
    @release = VersionRelease.new
    @release.attributes = release_params
    @release.save_attachments(params[:attachments])
    @release.author = User.current
    @release.status = :submitted
    @release.tested_mobile ||= params[:version_release][:tested_mobile].reject(&:blank?).join(',')
    @release.additional_note = params[:version_release_note]

    if @release.save
      respond_to do |format|
        format.html do
          render_attachment_warning_if_needed(@release)
          flash[:notice] = l(:notice_successful_create)
          redirect_to version_release_path(@release)
        end
        format.api { render json: @release.to_json }
      end
    else
      respond_to do |format|
        format.api { render_validation_errors(@release) }
        format.html { render :action => 'new' }
      end
    end
  end

  def show
  end

  def edit
  end

  def update
    @release = VersionRelease.find(params[:id])
    @release.save_attachments(params[:attachments] || (params[:version_release] && params[:version_release][:uploads]))
    @release.attributes = update_release_params if params[:version_release]
    if @release.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to version_release_path(@release)
    end
  end

  def version_lists
    specs = $db.slave { @project.specs.undeleted }
    specs_hash = $db.slave { specs.select(:id, :name) } if params[:spec_id].nil? && params[:version_id].nil?
    spec = $db.slave { Spec.find_by(id: params[:spec_id]) || (specs.first if specs.present?) }
    versions_hash = if params[:version_id].nil?
                      if spec.nil?
                        versions = []
                      else
                        category = VersionRelease.consts[:category].invert[params[:category].to_i]
                        versions = $db.slave { spec.versions.releasable(category) }
                        versions.map { |v| {:id => v.id, :name => v.name} }.unshift({:id => 0, :name => "--请选择--"})
                      end
                    end

    version = $db.slave { Version.find_by(id: params[:version_id]) || (versions.first if versions.present?) }
    tested_mobile_hash = if version.nil?
                           []
                         else
                           projects = params[:category].to_i == 1 ? $db.slave { Project.default } : $db.slave { version.releasable_projects }
                           projects.select(:id, :name).unshift({:id => '', :name => ''})
                         end

    parent_release = VersionRelease.find_parent(params[:version_id], params[:category]) if params[:category].to_i == 2
    parent_release_hash = {id: parent_release.id} if parent_release.present?
    render :json => {spec: specs_hash, version: versions_hash, tested_mobile: tested_mobile_hash, adapt_notice: parent_release_hash}
  end

  def rerelease
    @release = VersionRelease.find_by(:id => params[:id])
    @released_message = l(:version_release_rerelease_failed)
    if @release.completed?
      @release.status = "rereleasing"
      @release.author = User.current
      @release.result = nil
      @release.notes = nil # Just note the statue changes
      @release.tested_mobile = (@release.category.to_i == 1 ? Project.default : @release.version.releasable_projects).map(&:id).join(',')
      @released_message = l(:version_release_rerelease_done) if @release.save
    end
    respond_to do |format|
      format.js
    end
  end

  def view_log
    @release = VersionRelease.find_by(:id => params[:id])
    @log = @release.parse_log(params[:md5]) if /[0-9a-f]{32}/ === params[:md5]
    render :json => @log
  end

  def reset_problem
    @release = VersionRelease.find_by(:id => params[:id])
    @release.update(has_problem: false)
    respond_to do |format|
      format.js
    end
  end

  def version_apks
    version = $db.slave { Version.find(params[:version_id]) } if params[:version_id].to_i > 0
    not_apks = []
    applist_flag = 0
    if version && $db.slave { ReposHelper.get_repos_by_version_id(version.id) }.find{|repo| repo['android_platform'].to_i == ApkBase::APK_BASE_ANDROID_PLATFORM[:o_platform]}
      applist_flag = 1 if version.app_lists.blank?
      version.app_lists.map(&:apk_name).each { |apk|
        not_apks << apk if $db.slave { ApkBase.joins(:project_apk).where("android_platform = #{ApkBase::APK_BASE_ANDROID_PLATFORM[:o_platform]} and name = '#{apk}' and deleted = 0") }.blank?
      }
    end

    render :json => {apks: not_apks, flag: applist_flag}
  end

  private

  def release_params
    params.require(:version_release)
        .permit(
            :category,
            :version_id,
            :version_applicable_to,
            :tested_mobile,
            :test_finished_on,
            :test_type,
            :bvt_test,
            :fluency_test,
            :response_time_test,
            :sonar_codes_check,
            :app_standby_test,
            :monkey_72_test,
            :memory_leak_test,
            :cts_test,
            :cts_verifier_test,
            :interior_invoke_warning,
            :related_invoke_warning,
            :relative_objects,
            :codes_reviewed,
            :cases_sync_updated,
            :issues_for_platform,
            :code_walkthrough_well,
            :mode,
            :sdk_review,
            :description,
            :remaining_issues,
            :new_issues,
            :ued_confirm,
            :note,
            :uir_upload_to_svn,
            :mail_receivers,
            :translate_sync,
            :output_record_sync,
            :app_data_test,
            :app_launch_test,
            :translate_autocheck_result
        )
  end

  def update_release_params
    params.require(:version_release).permit(:status, :notes)
  end

  def find_project_from_params
    case params[:action]
      when 'show', 'rerelease', 'update', 'edit'
        release = VersionRelease.find_by(:id => params[:id])
        @project = release.project
      when 'create'
        version = Version.find_by(:id => params[:version_release][:version_id])
        @project = version.project
      else
        @project = Project.find(params[:project_id])
    end
  end

  def find_model_object
    @release = VersionRelease.find(params[:id])
  end

end
