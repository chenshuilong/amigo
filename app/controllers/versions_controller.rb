
# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class VersionsController < ApplicationController
  menu_item :roadmap
  model_object Version
  before_action :find_model_object, :except => [:index, :new, :create, :close_completed, :jenkins, :generate_name, :specs, :ota_increase_versions, :search, :choose, :compare, :app_infos]
  before_action :find_project_from_association, :except => [:index, :new, :create, :close_completed, :jenkins, :generate_name, :specs, :ota_increase_versions, :search, :choose, :compare, :app_infos]
  before_action :find_project_by_project_id, :only => [:index, :new, :create, :close_completed, :generate_name, :ota_increase_versions]
  before_action :authorize, :except => [:jenkins, :generate_name, :change, :unit_test_report, :upload_unit_test_report, :specs, :ota_increase_versions, :search, :choose, :compare, :search_repo_info, :app_infos]
  skip_before_action :check_if_login_required, :only => [:jenkins, :generate_name, :change, :unit_test_report, :upload_unit_test_report, :specs, :ota_increase_versions, :search, :choose, :compare, :search_repo_info, :app_infos]

  skip_before_action :verify_authenticity_token, :only => [:upload_unit_test_report, :search]

  accept_api_auth :index, :show, :create, :update, :destroy, :change

  helper :sort
  include SortHelper
  helper :custom_fields
  helper :projects

  #layout "faster_new", only: [:choose]

  def index
    sort_init 'id', 'desc'
    sort_update %w(id priority compile_status status name compile_machine signature compile_type
                   compile_start_on compile_end_on compile_due_on ota_increase_compile author_id )
    respond_to do |format|
      format.html {

        @limit = per_page_option
        @compile_status = params[:compile_status]
        @status = params[:status]
        @as_increase_version = params[:as_increase_version]
        @ota_whole_compile = params[:ota_whole_compile]
        @ota_increase_compile = params[:ota_increase_compile]
        @spec = params[:spec]
        @signature = params[:signature]
        @created_at_start = params[:created_at_start]
        @created_at_end = (Date.parse(params[:created_at_end]) + 1).to_s if params[:created_at_end].present?

        scope = $db.slave { @project.versions.includes(:releases).compile_status(@compile_status) }
        scope = $db.slave { scope.where(:as_increase_version => @as_increase_version) } if @as_increase_version.present?
        scope = $db.slave { scope.where(:spec_id => @spec) } if @spec.present?
        scope = $db.slave { scope.where("name LIKE '%#{params[:name]}%'") } if params[:name].present?
        scope = $db.slave { scope.where(:created_on => @created_at_start..@created_at_end) } if @created_at_start.present?
        scope = $db.slave { scope.where(:status => @status) } if @status.present?
        scope = $db.slave { scope.where("ifnull(signature, 0) = #{@signature}") } if @signature.present?
        scope = $db.slave { scope.where("ifnull(ota_whole_compile, 0) = #{@ota_whole_compile}") } if @ota_whole_compile.present?
        scope = $db.slave { scope.where("ifnull(ota_increase_compile, 0) = #{@ota_increase_compile}") } if @ota_increase_compile.present?

        @version_count = scope.count
        @version_pages = Paginator.new @version_count, @limit, params['page']
        @offset ||= @version_pages.offset
        @versions =  $db.slave { scope.reorder(sort_clause).limit(@limit).offset(@offset).to_a }

        # @trackers = @project.trackers.sorted.to_a
        # retrieve_selected_tracker_ids(@trackers, @trackers.select {|t| t.is_in_roadmap?})
        # @with_subprojects = params[:with_subprojects].nil? ? Setting.display_subprojects_issues? : (params[:with_subprojects] == '1')
        # project_ids = @with_subprojects ? @project.self_and_descendants.collect(&:id) : [@project.id]

        # @versions = @project.shared_versions || []
        # @versions += @project.rolled_up_versions.visible if @with_subprojects
        # @versions = @versions.uniq.sort
        # unless params[:completed]
        #   @completed_versions = @versions.select(&:completed?)
        #   @versions -= @completed_versions
        # end

        # @issues_by_version = {}
        # if @selected_tracker_ids.any? && @versions.any?
        #   issues = Issue.visible.
        #     includes(:project, :tracker).
        #     preload(:status, :priority, :fixed_version).
        #     where(:tracker_id => @selected_tracker_ids, :project_id => project_ids, :fixed_version_id => @versions.map(&:id)).
        #     order("#{Project.table_name}.lft, #{Tracker.table_name}.position, #{Issue.table_name}.id")
        #   @issues_by_version = issues.group_by(&:fixed_version)
        # end
        # @versions.reject! {|version| !project_ids.include?(version.project_id) && @issues_by_version[version].blank?}
      }
      format.api {
        @versions = $db.slave { @project.shared_versions.to_a }
      }
    end
  end

  def show
    respond_to do |format|
      format.html {
        # @issues = @version.fixed_issues.visible.
        #   includes(:status, :tracker, :priority).
        #   reorder("#{Tracker.table_name}.position, #{Issue.table_name}.id").
        #   to_a
        @issues    = $db.slave { @version.issues }
        @app_lists = $db.slave { VersionApplist.infos_by_apk_base(@version.id) }
      }
      format.api
    end
  end

  def new
    @version = @project.versions.build
    @version.name = @project.default_version_name if @version.name.blank?
    @version.priority ||= Version::VERSION_PRIORITY[:normal]
    @version.auto_test ||= false
    @version.ota_whole_compile ||= true
    @version.ota_increase_compile ||= false
    @version.safe_attributes = params[:version]

    @default_values = User.current.default_values.version
    respond_to do |format|
      format.html
      format.js
    end
  end

  def create
    @version = @project.versions.build
    if params[:version]
      attributes = params[:version].dup
      # Generate version name by rule for auto generate version
      attributes[:gradle_version] = nil if attributes[:repo_two_id].present? && Repo.find_by(id: attributes[:repo_two_id].to_i).try(:url).exclude?('gradle')
      
      if attributes[:rule_id].present?
        attributes.delete('name')
        rule_range        = VersionNameRule.find(attributes[:rule_id]).range
        attributes[:name] = rule_range.present? ? @project.generate_version_name(@project.android_platform.to_i == 2 ? attributes[:spec_id] : nil, rule_range) : Time.now.strftime('T%Y%m%d%H%M%S')
      end

      attributes.delete('sharing') unless attributes.nil? || @version.allowed_sharings.include?(attributes['sharing'])
      @version.safe_attributes = attributes
    end

    @version.author ||= User.current
    @version.status = Version::VERSION_STATUS[:planning]
    @version.compile_status = @version.compile_due_on.present?? Version.consts[:compile_status][:submitted] : Version.consts[:compile_status][:queued]
    @version.compile_due_on ||= Time.now
    @version.as_increase_version = false

    if request.post?
      spec_ids = Array.wrap(params[:version][:spec_id]).reject(&:blank?)
      saved_status = true # init saved status
      if spec_ids.size <= 1
        @version.spec_id = spec_ids.first
        saved_status = @version.save
      else # Bulk create
        @base_version = @version
        begin
          uniq_id = SecureRandom.uuid
          Version.transaction do
            spec_ids.each do |spec_id|
              @version = @base_version.dup
              @version.spec_id = spec_id
              @version.group_key = uniq_id
              @version.save!
            end
          end
        rescue
          saved_status = false
        end
      end

      if saved_status
        respond_to do |format|
          format.html do
            flash[:notice] = l(:notice_successful_create)
            redirect_back_or_default project_versions_path(@project)
          end
          format.js
          format.api do
            render :action => 'show', :status => :created, :location => version_url(@version)
          end
        end
      else
        respond_to do |format|
          format.html { render :action => 'new' }
          format.js   { render :action => 'new' }
          format.api  { render_validation_errors(@version) }
        end
      end
    end
  end

  def edit
    if params[:format].present? && params[:format] == 'js'
      if (version_params = params[:version]).present?
        @version.status = version_params[:status]                           if version_params[:status].present?
        @version.as_increase_version = version_params[:as_increase_version] if version_params[:as_increase_version].present?
        @version.description = version_params[:description]                 if version_params[:description].present?
        @version.sendtest_at = version_params[:sendtest_at]                 if version_params[:sendtest_at].present?
      end
      render "edit"
    end
  end

  def update
    if params[:version]
      params[:version][:sendtest_at] = nil if params[:version].present? && params[:version][:status].present? && params[:version][:status].to_i != 7
      attributes = params[:version].dup
      # attributes.delete('sharing') unless @version.allowed_sharings.include?(attributes['sharing'])
      attributes.slice!(:description, :status, :as_increase_version, :sendtest_at) unless @version.free_edit?
      attributes[:gradle_version] = nil if attributes[:repo_two_id].present? && Repo.find_by(id: attributes[:repo_two_id].to_i).try(:url).exclude?('gradle')

      # Remove rule_id from params
      attributes.delete("rule_id") if attributes.has_key?('rule_id')

      if @version.free_edit?
        @version.compile_status = attributes[:compile_due_on].present?? Version.consts[:compile_status][:submitted] : Version.consts[:compile_status][:queued]
      end

      # Check only description can be updated when compiling
      attributes = attributes.reject { |k, v| k != "description" } if @version.is_compiling?

      @version.safe_attributes = attributes

      if @version.save
        respond_to do |format|
          format.html {
            # !@version.is_compiling? ? flash[:notice] = l(:notice_successful_update) : flash[:error] = l(:version_failed_to_update)
            flash[:notice] = l(:notice_successful_update)
            redirect_back_or_default version_path(@version)
          }
          format.api  { render_api_ok }
        end
      else
        respond_to do |format|
          format.html { render :action => 'edit' }
          format.api  { render_validation_errors(@version) }
        end
      end
    end
  end

  def close_completed
    if request.put?
      @project.close_completed_versions
    end
    redirect_to project_versions_path(@project)
  end

  def destroy
    if @version.deletable?
      @version.destroy
      respond_to do |format|
        format.html { redirect_back_or_default project_versions_path(@project) }
        format.api  { render_api_ok }
      end
    else
      respond_to do |format|
        format.html {
          flash[:error] = l(:notice_unable_delete_version)
          redirect_to project_versions_path(@project)
        }
        format.api  { head :unprocessable_entity }
      end
    end
  end

  def status_by
    respond_to do |format|
      format.html { render :action => 'show' }
      format.js
    end
  end

  # Provide version lists for jenkins to compile
  def jenkins
    auth :version if request.formats[0].symbol == :html
    ownership            = params[:ownership].to_s.split(//)
    project_type         = params[:project_type].to_s.split(//)
    production_type      = params[:production_type].to_s.split(//)
    compile_status       = params[:compile_status].to_s.split(//)
    status               = params[:status].to_s.split(//)
    priority             = params[:priority].to_s.split(//)
    name                 = params[:name].to_s
    one_by_one           = params[:one_by_one]
    @author              = params[:author]
    spec                 = params[:spec]
    as_increase_version  = params[:as_increase_version]
    signature            = params[:signature]
    ota_whole_compile    = params[:ota_whole_compile]
    ota_increase_compile = params[:ota_increase_compile]
    coverity             = params[:coverity]
    project_category     = params[:project_category]
    @project_name        = params[:project_name]
    created_at_start     = params[:created_at_start]
    created_at_end       = (Date.parse(params[:created_at_end]) + 1).to_s if params[:created_at_end].present?
    @identifier          = params[:project_ids].to_s.split("|") if params[:project_ids].present?

    Version.check_if_time_to_compile # Update versions
    scope = Version.all

    scope = scope.like(name)                                                          if name.present?
    scope = scope.where(status: status)                                               if status.present?
    scope = scope.where(priority: priority)                                           if priority.present?
    scope = scope.where(compile_status: compile_status)                               if compile_status.present?
    scope = scope.joins(:project).where(projects: {ownership: ownership})             if ownership.present?
    scope = scope.joins(:project).where(projects: {category: project_type})           if project_type.present?
    scope = scope.joins(:project).where(projects: {production_type: production_type}) if production_type.present?
    scope = scope.joins(:author).where(users: {id: @author})                          if @author.present?
    scope = scope.where(spec_id: spec)                                                if spec.present?
    scope = scope.where(as_increase_version: as_increase_version)                     if as_increase_version.present?
    scope = scope.where(signature: signature)                                         if signature.present?
    scope = scope.where(ota_whole_compile: ota_whole_compile)                         if ota_whole_compile.present?
    scope = scope.where(ota_increase_compile: ota_increase_compile)                   if ota_increase_compile.present?
    scope = scope.where(coverity: coverity.to_i)                                      if coverity.present?
    scope = scope.project_category(project_category)                                  if project_category.present?
    scope = scope.where(:project_id => @project_name)                                 if @project_name.present?
    scope = scope.where(:created_on => created_at_start..created_at_end)              if created_at_start.present?

    if one_by_one.present? # For Modem and Framwork, to compile after one of them completed, NOTE: need add compile_status: 4 in query condition
      scope = scope.group("case when group_key IS NULL then versions.id else group_key end")
                   .having("locate(#{Version.consts[:compile_status][:compiling]}, group_concat(compile_status))<=0")
    end

    respond_to do |format|
      format.html{
        sort_init 'id', 'desc'
        sort_update %w(id priority compile_status name compile_machine signature compile_type
                   compile_start_on compile_end_on compile_due_on author_id )
        @limit = params[:per_page].present? ? params[:per_page].to_i : 25
        @page = params[:page].present? ? params[:page].to_i : 1
        @offset = (@page-1) * @limit
        @count = scope.count
        @pages = Paginator.new @count, @limit, @page
        @versions =  scope.reorder(sort_clause).limit(@limit).offset(@offset).to_a
        @select_projects = Project.categories(project_category)
        @select_specs = Spec.version_search(project_category, @project_name)
      }
      format.api {
        scope = scope.joins(:project).where(projects: {identifier: @identifier}) if @identifier.present?
        @versions = scope.reorder(priority: :asc, created_on: :asc).limit(params[:max_num].to_i)
      }
    end
  end

  # Refresh spec select options in index page to query versions
  def specs
    @project_category = params[:category]
    @project_name = params[:name]
    @select_specs = $db.slave { Spec.version_search(@project_category, @project_name) }

    respond_to do |format|
      format.js
    end
  end

  # For Jenkins to update version or fixed issues etc.
  def change
    if params[:token].in? [Token::SCM_TOKEN, Token::BEIYAN_VERSION_TOKEN]
      has = -> (key) { params.has_key?(key) }
      if has.(:version) # Update Version
        saved = @version.update(allow_jenkins_update_params)
        # logger.info "saved: #{saved}"
        # logger.info "version: #{@version}"
        # heihei = @version.errors.full_messages
        # logger.info "version error: #{heihei}"
      elsif has.(:issues) # Update Issue
        saved = @version.save_fixed_issues(params[:issues])
      elsif has.(:applist) # Update Applist
        saved = @version.save_applist(params[:applist])
      elsif has.(:yaml)
        saved = @version.update_yaml(params)
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

  def generate_name
    spec_id = params[:spec_id]
    prefix = params[:prefix]
    @name = @project.generate_version_name(spec_id, prefix)
    respond_to do |format|
      format.js
    end
  end

  # def ota_increase_versions
  #   version_params = [params[:version][:spec_id], params[:version][:repo_one_id]]
  #   versions = @project.versions
  #                      .where("as_increase_version = 1 AND spec_id = ? AND repo_one_id = ?", *version_params)
  #                      .where(:repo_two_id => params[:version][:repo_two_id])
  #   render :json => versions.pluck(:name)
  # end

  def stop_compiling
    @version = Version.find_by(id: params[:id])
    if @version.is_compiling?
      log_url = @version.log_url
      if /\/job\/(\w+)\/(\d+)/ === log_url
        job_name, job_number = $1, $2
        # Stop remote compiling job
        begin
          @jenkins = Api::Jenkins.new
          @jenkins.stop_job(job_name, job_number)
          @version.update_stopped_compile
        rescue
          logger.info("[#{Time.now.to_s(:db)}] Failed to stop remote compiling job!")
        end
      end
    end
    respond_to do |format|
      format.js
    end
  end

  # Page to display apk unit test report
  def unit_test_report
    unless params[:filepath].present? || request.original_url.match(/\/$/)
      redirect_to url_for(params.merge(:trailing_slash => true))
    end
  end

  # Upload unit test report of certain apk
  def upload_unit_test_report
    if params[:token] == Token::AUTO_TEST_TOKEN
      file_save_status = @version.save_utr_file(params[:file]) # if @version.unit_test?
      if file_save_status
        @version.update_column(:has_unit_test_report, true)
        render :text => "File saved!"
      else
        render_error :status => 500, :message => "Request failed!"
      end
    else
      render_error :status => 422, :message => "Invalid authenticity token."
    end
  end

  # Providing select2_remote to load versions when format.js , and redirect to version by fullname when format.html
  def search
    respond_to do |format|
      version_name = params[:name]
      format.html {
        if /\AT/ === version_name
          project = Project.find(params[:project_id])
          version = project.hm_versions.where("versions.name = ?", version_name).first
        elsif /\_T\d+/ === version_name
          version = Version.find_by_fullname(version_name)
        end

        version ? redirect_to(version_path(version.id)) : render(:text => l(:version_error_not_found))
      }
      format.js {
        if params[:project_id].present?
          project = Project.find(params[:project_id])
          scope =  project.hm_versions.compile_status(6)
                          .where("versions.name LIKE '%#{version_name}%'")
                          .reorder("versions.name DESC")
        else
          #获取所有终端版本信息，可按需继续扩展
          scope = Version.terminal_versions.where("versions.name LIKE '%#{version_name}%' OR specs.name LIKE '%#{version_name}%' OR projects.name LIKE '%#{version_name}%'")
        end
        page     = params[:page] || 1
        limit    = 20
        offset   = (page.to_i - 1) * limit
        versions = scope.limit(limit)
                        .offset(offset)

        data = params[:project_id].present? ? versions.map{|v| {:id => v.name, :name => v.name}} : versions.map{|v| {:id => v.id, :name => v.name}}

        render :json => data
      }
    end
  end

  def choose
    @category   = params[:category]
    
    @projects = $db.slave { Project.categories(@category) }
    view_all = policy("#{params[:category] == 'terminal'? 'project' : 'production'}".to_sym).view_all?
    @projects = $db.slave { @projects.joins("inner join members on members.project_id = projects.id and members.user_id = #{User.current.id}") } unless view_all

    if params[:category] == 'terminal'
      @project_1 = params[:project_1]
      @project_2 = params[:project_2]
      @spec_1 = params[:spec_1]
      @spec_2 = params[:spec_2]

      if @project_1.present?
        scope_spec1 = $db.slave { @projects.find_by(id: @project_1.to_i).specs.undeleted.reorder("name") }
        @specs_1 = scope_spec1.pluck(:name, :id)

        @spec1 = $db.slave { scope_spec1.find_by(id: @spec_1) } if @spec_1.present?
        @versions_1 = $db.slave { @spec1.versions.success_versions.pluck(:name, :id) } if @spec1.present?
      end

      if @project_2.present?
        scope_spec2 = $db.slave { @projects.find_by(id: @project_2.to_i).specs.undeleted.reorder("name") }
        @specs_2 = scope_spec2.pluck(:name, :id)

        @spec2 = $db.slave { scope_spec2.find_by(id: @spec_2) } if @spec_2.present?
        @versions_2 = $db.slave { @spec2.versions.success_versions.pluck(:name, :id) } if @spec2.present?
      end

    elsif params[:category] == 'other'
      @project_1 = params[:project_1]
      @spec_1 = params[:spec_1]

      if @project_1.present?
        sql1 = "versions.project_id = #{@project_1.to_i}"
        sql2 = sql1 + " and specs.name = '#{@spec_1.split("_")[0]}' and replace(versions.name, CONCAT('.',SUBSTRING_INDEX(versions.name,'.',-1)), ' ') = '#{@spec_1.split("_")[1]}'" if @spec_1.present?
      end

      @specs_1 = $db.slave { Version.compare_choose(sql1) }.map(&:spec_list).join(",").split(",") if sql1.present?
      @versions_1 = $db.slave { Version.success_versions.compare_choose(sql2) }.map(&:version_list).join(",").split(",").each_slice(2).to_a if sql2.present?
    end

    render :choose, :layout => 'faster_new'
  end

  def compare
    @category = params[:category] || 'terminal'
    @type     = params[:type] || 'app'
    @version_ida = params[:version_ida].to_i
    @version_idb = params[:version_idb].to_i
    @version_ids = [@version_ida, @version_idb]

    @versions = $db.slave { Version.includes(:project).where(id: @version_ids) }
    @va = $db.slave { @versions.find_by(id: @version_ida) }
    @vb = $db.slave { @versions.find_by(id: @version_idb) }

    if @version_ids.present? && @version_ids.uniq.count == 2
      if @category == 'terminal' && @type == 'app' || @category == 'other'
        if @category == "terminal"
          sql = "version_id in (#{@version_ids.join(',')})"
          @applists = $db.slave { VersionApplist.two_version_compare(sql).compare_list_hash }
        elsif @category == "other"
          @app = $db.slave { @versions.first.project }
        end  

        result = can_compare_issues?(@versions)  

        unless result.include?(false)
          @start = $db.slave { @versions.first.created_on }
          @end = $db.slave { @versions.last.created_on }
          @issues = $db.slave { VersionIssue.includes(:issue).where(version_id: result).group("issue_id").reorder("created_at") }
        end
      elsif @category == 'terminal' && %w(apk system).include?(@type)
        case @type
        when 'apk'
          sql = "version_id in (#{@version_ids.join(',')}) AND apk_name <> ''"
          @apklists = $db.slave { VersionApplist.apk_size_compare(sql).reorder("apk_name").apk_version_list(@version_ida, @version_idb) }
        when 'system'          
          @systems = @versions.system_space_compare(@version_ida, @version_idb)
          
          sql = "version_id in (#{@version_ids.join(',')}) AND apk_name <> '' AND apk_size_comparable = 1"
          @apklists = $db.slave { VersionApplist.apk_size_compare(sql).apk_size_list(@version_ida, @version_idb) }
        end
      end
    end
  end

  def search_repo_info
    repo_one = @version.repo_one
    repo_two = @version.repo_two
    if @project.category != 4
       @android_repo = repo_one.try(:name)
       @package_repo = repo_two.try(:name)
       @server_ip    = "#{repo_one.url.split(/[":","@"]/)[2]}"
       result = {android_repo: @android_repo, package_repo: @package_repo, server_ip: @server_ip, addr: repo_one.url}
    else
      @server_ip = "#{repo_one.url.split(/[":","@"]/)[2]}"
      result = {server_ip: @server_ip}
    end
    render :json => result.to_json
  end

  def app_infos
    auth :version
    
    @app_ids = params[:app_ids]
    @version_ids = params[:version_ids]

    @apps = $db.slave { Project.categories('other').where(id: @app_ids) } if @app_ids.present?
    @versions = $db.slave { Version.terminal_versions.where(compile_status: 6, id: @version_ids).reorder("id asc") } if @version_ids.present?

    if @versions.present? && @apps.present?
      @app_infos = @versions.app_infos(@apps.pluck(:name))
      respond_to do |format|
        format.html do
          if params[:export] == 'true'
            version_head = []
            @versions.each do |version|
              version_head << {"app_versions_#{version.name}" => version.name}
            end
            rows = {}
            columns = [{"app_name" => "应用名称"}] + version_head      

            columns.each { |c| rows.merge!({c.keys.first => c.values.first}) }  

            send_data app_infos_to_xlsx(@app_infos, rows), {:disposition => 'attachment', :encoding => 'utf8',
                                                :stream => false, :type => 'application/xlsx',
                                                :filename => "#{l(:label_version_app_infos)}_#{Time.now.strftime('%Y%m%d%H%m%s')}.xlsx"}     
          end       
        end
      end
    end
  end

  private

  def retrieve_selected_tracker_ids(selectable_trackers, default_trackers=nil)
    if ids = params[:tracker_ids]
      @selected_tracker_ids = (ids.is_a? Array) ? ids.collect { |id| id.to_i.to_s } : ids.split('/').collect { |id| id.to_i.to_s }
    else
      @selected_tracker_ids = (default_trackers || selectable_trackers).collect {|t| t.id.to_s }
    end
  end

  def allow_jenkins_update_params
    jenkins_params = params.require(:version).permit(:name, :compile_status, :log_url, :compile_machine, :compile_start_on, :compile_end_on, :baseline, :path, :status, :label, :finger_print, :as_increase_version)
    jenkins_params[:system_space] = params[:version]["system_space"] if params[:version].present? && params[:version]["system_space"].present?
    return jenkins_params
  end

  def can_compare_issues?(versions)
    @version_obj     = versions.first
    @version_compare = versions.last

    result = @version_compare.get_history_versions(@version_obj, [@version_compare.id], Time.now + 10.second)
    return result
  end

  def app_infos_to_xlsx(items, columns)
    items = items || []
    # New xlsx
    package = Axlsx::Package.new
    workbook = package.workbook

    # Style
    styles = workbook.styles
    heading = styles.add_style :border => {:style => :thin, :color => "000000"}, b: true, sz: 12, bg_color: "F77609", fg_color: "FF"
    body = styles.add_style alignment: {horizontal: :left}, :border => {:style => :thin, :color => "000000"}
    warning = styles.add_style alignment: {horizontal: :left}, :border => {:style => :thin, :color => "000000"}, bg_color: "ebccd1"
    notice = styles.add_style alignment: {horizontal: :left}, :border => {:style => :thin, :color => "000000"}, bg_color: "faebcc"

    # Workbook
    workbook.add_worksheet(name: "GIONEE") do |sheet|
      sheet.add_row (columns.values), style: heading

      items.each do |key, value|
        version = []
        @versions.each_with_index do |v, i|
          version << value[v.name.to_sym]
        end
        sheet.add_row [key]+version, style: body
      end
    end

    package.to_stream.read
  end
end
