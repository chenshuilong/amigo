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

class ProjectsController < ApplicationController
  menu_item :overview
  menu_item :settings, :only => :settings
  include Pundit

  before_filter :find_project, :except => [ :index, :list, :new, :create, :copy, :search ]
  before_filter :authorize, :except => [ :index, :list, :new, :create, :copy, :archive, :unarchive, :destroy, :same_custome_value, :members, :roles, :search]
  before_action :require_login
  before_filter :authorize_global, :only => [:new, :create]
  before_filter :require_admin, :only => [ :copy, :archive, :unarchive, :destroy]
  accept_rss_auth :index
  accept_api_auth :index, :show, :create, :update, :destroy
  require_sudo_mode :destroy

  after_filter :only => [:create, :edit, :update, :archive, :unarchive, :destroy] do |controller|
    if controller.request.post?
      controller.send :expire_action, :controller => 'welcome', :action => 'robots'
    end
  end

  helper :custom_fields
  helper :issues
  helper :queries
  helper :repositories
  helper :members

  # Lists visible projects
  def index

    # auth Project
    scope = $db.slave { request.formats[0].symbol.to_s == "html" ? Project.sorted.visible.default : Project.sorted.default }
    
    respond_to do |format|
      format.html {
        tab = params[:tab] || "group"
        unless params[:closed]
          scope = $db.slave { scope.active }
        end
        @projects = $db.slave { scope.projects_by_odm(tab).to_a }
      }
      format.api  {
        @offset, @limit = api_offset_and_limit
        scope = $db.slave { scope.where(:identifier => params[:name]) } if params[:name]
        @project_count = scope.count
        @projects = $db.slave { scope.offset(@offset).limit(@limit).to_a }
      }
      format.atom {
        projects = $db.slave { scope.reorder(:created_on => :desc).limit(Setting.feeds_limit.to_i).to_a }
        render_feed(projects, :title => "#{Setting.app_title}: #{l(:label_project_latest)}")
      }
    end
  end

  def new
    @issue_custom_fields = IssueCustomField.sorted.to_a
    @trackers = Tracker.sorted.to_a
    @project = Project.new
    @project.safe_attributes = params[:project]
    @project.category ||= 1
    respond_to do |format|
      format.js
      format.html { render :action => 'new', :layout => !request.xhr? }
    end
  end

  def create
    @issue_custom_fields = IssueCustomField.sorted.to_a
    @trackers = Tracker.sorted.to_a
    @project = Project.new
    @project.safe_attributes = params[:project]

    if @project.save
      unless User.current.admin?
        @project.add_default_member(User.current)
      end
      # Copy all members from a project
      # if params[:project][:copy_project_id].present? || params[:project][:parent_id].present?
      #   from_project_id = params[:project][:copy_project_id].blank? ? params[:project][:parent_id] : params[:project][:copy_project_id]
      #   @project.copy_project_members(from_project_id.to_i)
      # end

      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_successful_create)
          if params[:continue]
            attrs = {:parent_id => @project.parent_id}.reject {|k,v| v.nil?}
            redirect_to new_project_path(attrs)
          else
            redirect_to settings_project_path(@project)
          end
        }
        format.api  { render :action => 'show', :status => :created, :location => url_for(:controller => 'projects', :action => 'show', :id => @project.id) }
      end
    else
      respond_to do |format|
        format.html { render :action => 'new' }
        format.api  { render_validation_errors(@project) }
      end
    end
  end

  def copy
    @issue_custom_fields = IssueCustomField.sorted.to_a
    @trackers = Tracker.sorted.to_a
    @source_project = Project.find(params[:id])
    if request.get?
      @project = Project.copy_from(@source_project)
      @project.identifier = Project.next_identifier if Setting.sequential_project_identifiers?
    else
      Mailer.with_deliveries(params[:notifications] == '1') do
        @project = Project.new
        @project.safe_attributes = params[:project]
        if @project.copy(@source_project, :only => params[:only])
          flash[:notice] = l(:notice_successful_create)
          redirect_to settings_project_path(@project)
        elsif !@project.new_record?
          # Project was created
          # But some objects were not copied due to validation failures
          # (eg. issues from disabled trackers)
          # TODO: inform about that
          redirect_to settings_project_path(@project)
        end
      end
    end
  rescue ActiveRecord::RecordNotFound
    # source_project not found
    render_404
  end

  # Show @project
  def show
    auth @project if @project.category.to_i != 4

    ### View Project Record Start ###
    @project.add_view_record
    ### View Project Record End   ###
    
    # try to redirect to the requested menu item
    if params[:jump] && redirect_to_project_menu_item(@project, params[:jump])
      return
    end

    @users_by_role = $db.slave { @project.users_by_role(21) } #limit 21 records
    @subprojects = $db.slave { @project.children.visible.to_a }
    @news = $db.slave { @project.news.limit(5).includes(:author, :project).reorder("#{News.table_name}.created_on DESC").to_a }
    @trackers = $db.slave { @project.rolled_up_trackers }

    cond = $db.slave { @project.project_condition(Setting.display_subprojects_issues?) }

    # @open_issues_by_tracker = Issue.visible.open.where(cond).group(:tracker).count
    # @total_issues_by_tracker = Issue.visible.where(cond).group(:tracker).count
    @open_issues_by_tracker = $db.slave { Issue.visible.open.where(cond).group(:tracker_id).count }
    @total_issues_by_tracker = $db.slave { Issue.visible.where(cond).group(:tracker_id).count }

    if User.current.allowed_to_view_all_time_entries?(@project)
      @total_hours = $db.slave { TimeEntry.visible.where(cond).sum(:hours).to_f }
    end

    @key = User.current.rss_key

    #GMS
    @approveds = $db.slave { @project.versions.where(status: 7) }

    respond_to do |format|
      format.html
      format.api
    end
  end

  def settings
    @issue_custom_fields = $db.slave { IssueCustomField.sorted.to_a }
    @issue_category ||= IssueCategory.new
    @member ||= @project.members.new
    @trackers = $db.slave { Tracker.sorted.to_a }
    @wiki ||= @project.wiki || Wiki.new(:project => @project)
  end

  def edit
  end

  def update
    @project.safe_attributes = params[:project]
    if @project.save
      # Copy all members from a project
      # if params[:project][:copy_project_id].present? || params[:project][:parent_id].present?
      #   from_project_id = params[:project][:copy_project_id].blank? ? params[:project][:parent_id] : params[:project][:copy_project_id]
      #   @project.copy_project_members(from_project_id.to_i)
      # end

      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_successful_update)
          redirect_to settings_project_path(@project)
        }
        format.api  { render_api_ok }
      end
    else
      respond_to do |format|
        format.html {
          settings
          render :action => 'settings'
        }
        format.api  { render_validation_errors(@project) }
      end
    end
  end

  def modules
    @project.enabled_module_names = params[:enabled_module_names]
    flash[:notice] = l(:notice_successful_update)
    redirect_to settings_project_path(@project, :tab => 'modules')
  end

  def archive
    unless @project.archive
      flash[:error] = l(:error_can_not_archive_project)
    end
    redirect_to admin_projects_path(:status => params[:status])
  end

  def unarchive
    unless @project.active?
      @project.unarchive
    end
    redirect_to admin_projects_path(:status => params[:status])
  end

  def close
    @project.close
    redirect_to project_path(@project)
  end

  def reopen
    @project.reopen
    redirect_to project_path(@project)
  end

  # Delete @project
  def destroy
    @project_to_destroy = @project
    if api_request? || params[:confirm]
      @project_to_destroy.destroy
      respond_to do |format|
        format.html { redirect_to admin_projects_path }
        format.api  { render_api_ok }
      end
    end
    # hide project in layout
    @project = nil
  end

  def same_custome_value
    project = Project.find_by_identifier(params[:id])
    custom_field_id = params[:custom_field_id]
    case_id = params[:case_id]
    issues = project.same_custom_value(custom_field_id, case_id)
    json = issues.present?? issues.joins(:status, :author).select(:id, :name, :subject, :created_on, :firstname, :author_id) : nil
    render :json => json
  end

  def search 
    respond_to do |format|
      category = params[:category]
      production_type = params[:production_type]
      project_name = params[:name]
      format.js {
        scope = $db.slave { Project.active.visible.categories(category)
                       .where("projects.identifier LIKE '%#{project_name}%'")
                       .reorder("projects.id asc") }

        scope = $db.slave { scope.where(production_type: production_type) } if production_type.present?
        scope = $db.slave { scope.joins(:mokuai_ownners).where(mokuai_ownners: {mokuai_id: params[:mokuai_id]}) } if params[:mokuai_id].present?
        
        page     = params[:page] || 1
        limit    = 20
        offset   = (page.to_i - 1) * limit
        projects = $db.slave { scope.limit(limit).offset(offset) }
        render :json => projects.map{|v| {:id => v.id, :name => v.name}}
      }
    end
  end
end
