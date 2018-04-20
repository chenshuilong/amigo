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

class MyController < ApplicationController

  before_filter :require_login
  before_filter :require_admin, :only => :destroy
  # let user change user's password when user has to
  skip_before_filter :check_password_change, :only => :password
  before_filter :raise_error_without_logged, :only => [:add_favor, :remove_favor]

  require_sudo_mode :account, only: :post
  require_sudo_mode :reset_rss_key, :reset_api_key, :show_api_key, :destroy

  helper :issues
  helper :users
  helper :custom_fields

  BLOCKS = { 'issuesassignedtome' => :label_assigned_to_me_issues,
             'issuesreportedbyme' => :label_reported_issues,
             'issueswatched' => :label_watched_issues,
             'news' => :label_news_latest,
             'calendar' => :label_calendar,
             'documents' => :label_document_plural,
             # 'timelog' => :label_spent_time
           }.merge(Redmine::Views::MyPage::Block.additional_blocks).freeze

  # DEFAULT_LAYOUT = {  'left' => ['issuesassignedtome'],
  #                     'right' => ['issuesreportedbyme']
  #                  }.freeze

  DEFAULT_LAYOUT = {  "top"=>["issuesassignedtome", "issuesreportedbyme"],
                      "left"=>[],
                      "right"=>[]
                   }.freeze

  def index
    page
    render :action => 'page'
  end

  # Show user's page
  def page
    @blocks = current_user.pref[:my_page_layout] || DEFAULT_LAYOUT
    session[:return_to] = url_for(params)
  end

  def homepage
    @favors = current_user.favors
  end

  # Edit user's account
  def account
    @user = User.current
    @pref = @user.pref
    if request.post?
      @user.safe_attributes = params[:user].except(:name, :mail) if params[:user]
      @user.pref.attributes = params[:pref] if params[:pref]
      # Change Password
      if params[:user] && params[:user][:old_password]
        old_pass, new_pass = params[:user][:old_password], params[:user][:new_password]
        change_password_status = @user.change_password(old_pass, new_pass) if old_pass.present? && new_pass.present?
        password_notice = change_password_status == "true"? "，，密码修改成功。" : "，密码未更新。"
      end
      if @user.save
        @user.pref.save
        set_language_if_valid @user.language
        flash[:notice] = l(:notice_account_updated) + password_notice.to_s
        redirect_to my_account_path(:tab => params[:tab])
        return
      end
    end
  end

  def update_avatar
    @user = User.current
    @user.crop_size = params[:avatar].except(:file)
    @user.picture = params[:avatar][:file]
    if @user.save
      render :json => {:avatar_url => @user.picture.large.url}
    else
      render_error
    end
  end

  # Destroys user's account
  def destroy
    @user = User.current
    unless @user.own_account_deletable?
      redirect_to my_account_path
      return
    end

    if request.post? && params[:confirm]
      @user.destroy
      if @user.destroyed?
        logout_user
        flash[:notice] = l(:notice_account_deleted)
      end
      redirect_to home_path
    end
  end

  # Manage user's password
  def password
    @user = User.current
    unless @user.change_password_allowed?
      flash[:error] = l(:notice_can_t_change_password)
      redirect_to my_account_path
      return
    end
    if request.post?
      if !@user.check_password?(params[:password])
        flash.now[:error] = l(:notice_account_wrong_password)
      elsif params[:password] == params[:new_password]
        flash.now[:error] = l(:notice_new_password_must_be_different)
      else
        @user.password, @user.password_confirmation = params[:new_password], params[:new_password_confirmation]
        @user.must_change_passwd = false
        if @user.save
          # The session token was destroyed by the password change, generate a new one
          session[:tk] = @user.generate_session_token
          Mailer.password_updated(@user)
          flash[:notice] = l(:notice_account_password_updated)
          redirect_to my_account_path
        end
      end
    end
  end

  # Create a new feeds key
  def reset_rss_key
    if request.post?
      if User.current.rss_token
        User.current.rss_token.destroy
        User.current.reload
      end
      User.current.rss_key
      flash[:notice] = l(:notice_feeds_access_key_reseted)
    end
    redirect_to my_account_path
  end

  def show_api_key
    @user = User.current
  end

  # Create a new API key
  def reset_api_key
    if request.post?
      if User.current.api_token
        User.current.api_token.destroy
        User.current.reload
      end
      User.current.api_key
      flash[:notice] = l(:notice_api_access_key_reseted)
    end
    redirect_to my_account_path
  end

  # User's page layout configuration
  def page_layout
    @user = User.current
    @blocks = @user.pref[:my_page_layout] || DEFAULT_LAYOUT.dup
    @block_options = []
    BLOCKS.each do |k, v|
      unless @blocks.values.flatten.include?(k)
        @block_options << [l("my.blocks.#{v}", :default => [v, v.to_s.humanize]), k.dasherize]
      end
    end
  end

  # Add a block to user's page
  # The block is added on top of the page
  # params[:block] : id of the block to add
  def add_block
    block = params[:block].to_s.underscore
    if block.present? && BLOCKS.key?(block)
      @user = User.current
      layout = @user.pref[:my_page_layout] || {}
      # remove if already present in a group
      %w(top left right).each {|f| (layout[f] ||= []).delete block }
      # add it on top
      layout['top'].unshift block
      @user.pref[:my_page_layout] = layout
      @user.pref.save
    end
    redirect_to my_page_layout_path
  end

  # Remove a block to user's page
  # params[:block] : id of the block to remove
  def remove_block
    block = params[:block].to_s.underscore
    @user = User.current
    # remove block in all groups
    layout = @user.pref[:my_page_layout] || {}
    %w(top left right).each {|f| (layout[f] ||= []).delete block }
    @user.pref[:my_page_layout] = layout
    @user.pref.save
    redirect_to my_page_layout_path
  end

  # Change blocks order on user's page
  # params[:group] : group to order (top, left or right)
  # params[:list-(top|left|right)] : array of block ids of the group
  def order_blocks
    group = params[:group]
    @user = User.current
    if group.is_a?(String)
      group_items = (params["blocks"] || []).collect(&:underscore)
      group_items.each {|s| s.sub!(/^block_/, '')}
      if group_items and group_items.is_a? Array
        layout = @user.pref[:my_page_layout] || {}
        # remove group blocks if they are presents in other groups
        %w(top left right).each {|f|
          layout[f] = (layout[f] || []) - group_items
        }
        layout[group] = group_items
        @user.pref[:my_page_layout] = layout
        @user.pref.save
      end
    end
    render :nothing => true
  end

  def staffs
    auth :my

    Dept.new.update_dept_cache if $redis.smembers("amigo_depts").blank?
    @depts = $redis.smembers("amigo_depts")
  end

  def export_staffs
    raise "没有登录" unless User.current.logged?
    Export.create(:category => 2, :name => "#{l(:permission_export_my_staffs)}_#{Time.now.strftime('%s')}", :format => "xlsx", :options => {:ids => params[:ids]}, :lines => 0)

    render :text => {:success => 1, :message => "操作成功!"}.to_json
  rescue => e
    render :text => {:success => 0, :message => e.to_s}.to_json
  end

  def links
    auth :my
  end

  def tasks
    if params[:type].present?
      @limit = per_page_option
      case params[:type]
        when "issue_to_special_test_task"
          scope = $db.slave { Task.issue_to_special_test_tasks }
        when "personal_task"
          sql = if params[:person_type] == "author_id"
                  "tasks.author_id = #{User.current.id}"
                elsif params[:person_type] == "assigned_to_id"
                  "tasks.author_id <> #{User.current.id} AND tasks.assigned_to_id = #{User.current.id}"
                end
          scope = $db.slave { Task.personal_tasks(sql) }
        when "apk_base"
          scope = $db.slave { Task.apk_bases }
        when "patch_version_task"
          scope = $db.slave { Task.patch_versions }
      end

      @count = scope.to_a.count
      @pages = Paginator.new @count, @limit, params['page']
      @offset ||= @pages.offset
      @tasks = $db.slave { scope.limit(@limit).offset(@offset).reorder("created_at desc").to_a } if scope && params[:type] != "patch_version_task"

      if params[:type] == "library_update_task"
        library_files = $db.slave { Task.library_files }
        libraries = $db.slave { Task.update_libraries }

        @tasks = libraries.concat(library_files)
      elsif params[:type] == "patch_version_task"
        @tasks = $db.slave { scope.limit(@limit).offset(@offset).to_a } if scope
      elsif params[:type] == "library_merge_task"
      else
        @plan_tasks = $db.slave { Task.assigned_to_me(User.current.id, init_status_sql, "") }
        # @status = {:data => Task::ASSIGNED_STATUS.to_a.map { |status| {:name => status[1][1], :id => status[1][0]} }}.to_json
        @status = {:data => Task::TASK_STATUS.to_a.map { |status| {:name => status[1][1], :id => status[1][0]} }}.to_json
        @assigned_status = {:data => PlanTask::ASSIGNED_STATUS.to_a.map { |status| {:name => status[1][1], :id => status[1][0]} }}.to_json
        @spm_status = {:data => PlanTask::SPM_STATUS.to_a.map { |status| {:name => status[1][1], :id => status[1][0]} }}.to_json
        @checker_status = {:data => PlanTask::CONFIRM_STATUS.to_a.map { |status| {:name => status[1][1], :id => status[1][0]} }}.to_json
      end
    end
  end

  def add_favor
    current_user.favors << UserFavor.new(handle_url_without_prefix)

    render :text => {:success => 1, :message => "操作成功!"}.to_json
  rescue => e
    render :text => {:success => 0, :message => e.to_s}.to_json
  end

  def remove_favor
    favor = UserFavor.find(params[:id])
    favor.destroy if favor

    render :text => {:success => 1, :message => "操作成功!"}.to_json
  rescue => e
    render :text => {:success => 0, :message => e.to_s}.to_json
  end

  private

  def init_status_sql
    init_sql = ""
    init_sql << "tasks.status in (#{params[:status].to_s})" if params[:status]
    init_sql
  end

  def favor_add_params
    params.require(:favors).permit(:title, :url)
  end

  def handle_url_without_prefix
    favor_params = favor_add_params.dup
    if favor_params[:url].start_with?("http://") || favor_params[:url].start_with?("https://")

    else
      favor_params[:url] = "http://" + favor_params[:url]
    end
    favor_params
  end
end
