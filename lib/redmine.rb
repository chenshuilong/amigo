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

require 'redmine/core_ext'

begin
  require 'rmagick' unless Object.const_defined?(:Magick)
rescue LoadError
  # RMagick is not available
end
begin
  require 'redcarpet' unless Object.const_defined?(:Redcarpet)
rescue LoadError
  # Redcarpet is not available
end

require 'redmine/acts/positioned'

require 'redmine/scm/base'
require 'redmine/access_control'
require 'redmine/access_keys'
require 'redmine/activity'
require 'redmine/activity/fetcher'
require 'redmine/ciphering'
require 'redmine/codeset_util'
require 'redmine/field_format'
require 'redmine/menu_manager'
require 'redmine/notifiable'
require 'redmine/platform'
require 'redmine/mime_type'
require 'redmine/notifiable'
require 'redmine/search'
require 'redmine/syntax_highlighting'
require 'redmine/thumbnail'
require 'redmine/unified_diff'
require 'redmine/utils'
require 'redmine/version'
require 'redmine/wiki_formatting'

require 'redmine/default_data/loader'
require 'redmine/helpers/calendar'
require 'redmine/helpers/diff'
require 'redmine/helpers/gantt'
require 'redmine/helpers/time_report'
require 'redmine/views/other_formats_builder'
require 'redmine/views/labelled_form_builder'
require 'redmine/views/builders'

require 'redmine/themes'
require 'redmine/hook'
require 'redmine/hook/listener'
require 'redmine/hook/view_listener'
require 'redmine/plugin'

# Amigo Module
require 'redmine/amigo'

Redmine::Scm::Base.add "Subversion"
Redmine::Scm::Base.add "Darcs"
Redmine::Scm::Base.add "Mercurial"
Redmine::Scm::Base.add "Cvs"
Redmine::Scm::Base.add "Bazaar"
Redmine::Scm::Base.add "Git"
Redmine::Scm::Base.add "Filesystem"

# Permissions
Redmine::AccessControl.map do |map|
  map.permission :view_project, {:projects => [:show], :activities => [:index]}, :public => true, :read => true
  map.permission :search_project, {:search => :index}, :public => true, :read => true
  map.permission :add_project, {:projects => [:new, :create]}, :require => :loggedin
  map.permission :edit_project, {:projects => [:settings, :edit, :update]}, :require => :member
  map.permission :close_project, {:projects => [:close, :reopen]}, :require => :member, :read => true
  map.permission :select_project_modules, {:projects => :modules}, :require => :member
  map.permission :view_members, {:members => [:index, :show]}, :public => true, :read => true
  map.permission :manage_members, {:projects => :settings, :members => [:index, :show, :new, :create, :update, :destroy, :autocomplete]}, :require => :member
  map.permission :manage_versions, {:projects => :settings, :versions => [:new, :create, :edit, :update, :close_completed, :destroy, :stop_compiling], :repos => [:link, :unlink]}, :require => :member
  map.permission :release_versions, {:version_releases => [:new, :create, :rerelease, :edit], :attachments => :upload}, :require => :member
  map.permission :add_subprojects, {:projects => [:new, :create]}, :require => :member
  map.permission :members, {:members => [:members, :roles]}, :require => :member
  #map.permission :view_permissions, {:version_permissions => [:index, :destroy]}, :require => :member
  #map.permission :edit_permissions, {:version_permissions => [:index, :change, :save_change, :destroy]}, :require => :member
  #map.permission :view_publishes, {:version_publishes => [:index, :preview, :history, :show]}, :require => :member
  #map.permission :edit_publishes, {:version_publishes => [:index, :preview, :edit, :save_change, :history, :publish, :show]}, :require => :member


  map.project_module :issue_tracking do |map|
    # Issues
    map.permission :view_issues, {:issues => [:index, :show],
                                  :auto_complete => [:issues],
                                  :context_menus => [:issues],
                                  :versions => [:index, :show, :status_by],
                                  :journals => [:index, :diff],
                                  :queries => :index,
                                  :version_releases => :show,
                                  :reports => [:issue_report, :issue_report_details]},
                                  :read => true
    map.permission :add_issues, {:issues => [:new, :create], :attachments => :upload}
    map.permission :edit_issues, {:issues => [:edit, :update, :bulk_edit, :bulk_update], :journals => [:new], :attachments => :upload}
    map.permission :copy_issues, {:issues => [:new, :create, :bulk_edit, :bulk_update], :attachments => :upload}
    map.permission :manage_issue_relations, {:issue_relations => [:index, :show, :create, :destroy]}
    map.permission :manage_subtasks, {}
    map.permission :set_issues_private, {}
    map.permission :set_own_issues_private, {}, :require => :loggedin
    map.permission :add_issue_notes, {:issues => [:edit, :update], :journals => [:new], :attachments => :upload}
    map.permission :edit_issue_notes, {:journals => [:edit, :update]}, :require => :loggedin
    map.permission :edit_own_issue_notes, {:journals => [:edit, :update]}, :require => :loggedin
    map.permission :view_private_notes, {}, :read => true, :require => :member
    map.permission :set_notes_private, {}, :require => :member
    map.permission :delete_issues, {:issues => :destroy}, :require => :member
    # Queries
    map.permission :manage_public_queries, {:queries => [:new, :create, :edit, :update, :destroy]}, :require => :member
    map.permission :save_queries, {:queries => [:new, :create, :edit, :update, :destroy]}, :require => :loggedin
    # Watchers
    map.permission :view_issue_watchers, {}, :read => true
    map.permission :add_issue_watchers, {:watchers => [:new, :create, :append, :autocomplete_for_user]}
    map.permission :delete_issue_watchers, {:watchers => :destroy}
    map.permission :import_issues, {:imports => [:new, :create, :settings, :mapping, :run, :show]}
    # Issue categories
    map.permission :manage_categories, {:projects => :settings, :issue_categories => [:index, :show, :new, :create, :edit, :update, :destroy]}, :require => :member
  end

  map.project_module :time_tracking do |map|
    map.permission :view_time_entries, {:timelog => [:index, :report, :show]}, :read => true
    map.permission :log_time, {:timelog => [:new, :create]}, :require => :loggedin
    map.permission :edit_time_entries, {:timelog => [:edit, :update, :destroy, :bulk_edit, :bulk_update]}, :require => :member
    map.permission :edit_own_time_entries, {:timelog => [:edit, :update, :destroy,:bulk_edit, :bulk_update]}, :require => :loggedin
    map.permission :manage_project_activities, {:project_enumerations => [:update, :destroy]}, :require => :member
  end

  map.project_module :news do |map|
    map.permission :view_news, {:news => [:index, :show]}, :public => true, :read => true
    map.permission :manage_news, {:news => [:new, :create, :edit, :update, :destroy], :comments => [:destroy], :attachments => :upload}, :require => :member
    map.permission :comment_news, {:comments => :create}
  end

  map.project_module :documents do |map|
    map.permission :view_documents, {:documents => [:index, :show, :download]}, :read => true
    map.permission :add_documents, {:documents => [:new, :create, :add_attachment], :attachments => :upload}, :require => :loggedin
    map.permission :edit_documents, {:documents => [:edit, :update, :add_attachment], :attachments => :upload}, :require => :loggedin
    map.permission :delete_documents, {:documents => [:destroy]}, :require => :loggedin
  end

  map.project_module :files do |map|
    map.permission :view_files, {:files => :index, :versions => :download}, :read => true
    map.permission :manage_files, {:files => [:new, :create], :attachments => :upload}, :require => :loggedin
  end

  map.project_module :wiki do |map|
    map.permission :view_wiki_pages, {:wiki => [:index, :show, :special, :date_index]}, :read => true
    map.permission :view_wiki_edits, {:wiki => [:history, :diff, :annotate]}, :read => true
    map.permission :export_wiki_pages, {:wiki => [:export]}, :read => true
    map.permission :edit_wiki_pages, :wiki => [:new, :edit, :update, :preview, :add_attachment], :attachments => :upload
    map.permission :rename_wiki_pages, {:wiki => :rename}, :require => :member
    map.permission :delete_wiki_pages, {:wiki => [:destroy, :destroy_version]}, :require => :member
    map.permission :delete_wiki_pages_attachments, {}
    map.permission :protect_wiki_pages, {:wiki => :protect}, :require => :member
    map.permission :manage_wiki, {:wikis => [:edit, :destroy]}, :require => :member
  end

  map.project_module :repository do |map|
    map.permission :view_changesets, {:repositories => [:show, :revisions, :revision]}, :read => true
    map.permission :browse_repository, {:repositories => [:show, :browse, :entry, :raw, :annotate, :changes, :diff, :stats, :graph]}, :read => true
    map.permission :commit_access, {}
    map.permission :manage_related_issues, {:repositories => [:add_related_issue, :remove_related_issue]}
    map.permission :manage_repository, {:repositories => [:new, :create, :edit, :update, :committers, :destroy]}, :require => :member
  end

  map.project_module :boards do |map|
    map.permission :view_messages, {:boards => [:index, :show], :messages => [:show]}, :public => true, :read => true
    map.permission :add_messages, {:messages => [:new, :reply, :quote], :attachments => :upload}
    map.permission :edit_messages, {:messages => :edit, :attachments => :upload}, :require => :member
    map.permission :edit_own_messages, {:messages => :edit, :attachments => :upload}, :require => :loggedin
    map.permission :delete_messages, {:messages => :destroy}, :require => :member
    map.permission :delete_own_messages, {:messages => :destroy}, :require => :loggedin
    map.permission :manage_boards, {:boards => [:new, :create, :edit, :update, :destroy]}, :require => :member
  end

  map.project_module :calendar do |map|
    map.permission :view_calendar, {:calendars => [:show, :update]}, :read => true
  end

  map.project_module :gantt do |map|
    map.permission :view_gantt, {:gantts => [:show, :update]}, :read => true
  end

  map.project_module :mokuai_ownners do |map|
    map.permission :view_mokuai_ownners, {:mokuai_ownners => :index}, :public => true, :read => true
    map.permission :add_mokuai_ownners, {:mokuai_ownners => [:create, :update, :destroy]}, :read => true
  end

  map.project_module :specs do |map|
    map.permission :view_specs, {:specs => :index}, :public => true, :read => true
    map.permission :add_specs, {:specs => [:create, :update, :destroy]}, :read => true
    map.permission :add_apps, {:specs => [:freezeapp,:editapp,:udapp,:delapp]}, :read => true
    map.permission :collect_specs, {:specs => [:reset,:lock,:cllect]}, :read => true
  end

  map.project_module :definitions do |map|
    map.permission :view_definition, {:definitions => :index}, :read => true
    map.permission :new_product_definition, {:definitions => :new, :attachments => :upload}, :read => true
    map.permission :copy_product_definition, {:definitions => :copy, :attachments => :upload}, :read => true
    map.permission :manage_product_definition, {:definitions => :create_custom_value, :attachments => :upload}, :read => true
    map.permission :manage_definition_module, {:definitions => :create_definition_module, :attachments => :upload}, :read => true
    map.permission :manage_definition_custom_field, {:definitions => :create_custom_field, :attachments => :upload}, :read => true
    map.permission :manage_definition_module_field, {:definitions => :create_module_field, :attachments => :upload}, :read => true
    map.permission :manage_compare_model, {:definitions => :create_compare_model, :attachments => :upload}, :read => true
  end

  map.project_module :plans do |map|
    map.permission :view_plans, {:plans => :index}, :read => true
    map.permission :edit_plans, {:plans => [:edit, :send_task, :destroy]}, :read => true
  end

  map.project_module :issue_to_approve_merges do |map|
    map.permission :view_issue_to_merges, {:issue_to_approve_merges => :index}, :read => true
    map.permission :edit_issue_to_merges, {:issue_to_approve_merges => [:edit, :send_task, :destroy]}, :read => true
  end

  map.project_module :apk_bases do |map|
    map.permission :view_apk_bases, {:apk_bases => :apks}, :read => true
    map.permission :edit_apk_bases, {:apk_bases => [:new, :create, :edit, :update, :destroy]}, :read => true
  end
end

Redmine::MenuManager.map :top_menu do |menu|
  # menu.push :home, :home_path
  menu.push :my_page, { :controller => 'my', :action => 'homepage' }, :html => {"data-toggle" => "tabs"}, :if => Proc.new { User.current.logged? }
  menu.push :projects, { :controller => 'projects', :action => 'index' }, :html => {"data-toggle" => "tabs"}, :caption => :label_project_plural
  menu.push :defectives, :issues_path, :html => {"data-toggle" => "tabs"}, :caption => :label_defectives
  menu.push :productions, :productions_path, :caption => :label_productions, :html => {"data-toggle" => "tabs"}
  menu.push :repos, :repos_path, :caption => :label_repos, :html => {"data-toggle" => "tabs"}
  # menu.push :processes, :criterions_path, :caption => :label_processes, :html => {"data-toggle" => "tabs"}
  menu.push :demands, :demands_path, :caption => :label_library, :html => {"data-toggle" => "tabs"}
  menu.push :processes, :flow_files_path, :caption => :label_processes, :html => {"data-toggle" => "tabs"}
  menu.push :sharing, :tools_path, :caption => :label_shares, :html => {"data-toggle" => "tabs"}
  menu.push :help, :help_path, :caption => :label_help, :html => {"data-toggle" => "tabs"}
  menu.push :administration, { :controller => 'admin', :action => 'index' }, :html => {"data-toggle" => "tabs"}, :if => Proc.new { User.current.admin? }, :last => true
end

Redmine::MenuManager.map :account_menu do |menu|
  menu.push :login, :signin_path, :if => Proc.new { !User.current.logged? }
  # menu.push :register, :register_path, :if => Proc.new { !User.current.logged? && Setting.self_registration? }
  menu.push :my_account, { :controller => 'my', :action => 'account' }, :if => Proc.new { User.current.logged? }
  menu.push :logout, :signout_path, :html => {:method => 'post'}, :if => Proc.new { User.current.logged? }
end

Redmine::MenuManager.map :application_menu do |menu|
  # Empty
end

Redmine::MenuManager.map :admin_menu do |menu|
  menu.push :projects, {:controller => 'admin', :action => 'projects'}, :caption => :label_project_plural
  menu.push :users, {:controller => 'users'}, :caption => :label_user_plural
  menu.push :groups, {:controller => 'groups'}, :caption => :label_group_plural
  menu.push :roles, {:controller => 'roles'}, :caption => :label_role_and_permissions
  menu.push :trackers, {:controller => 'trackers'}, :caption => :label_tracker_plural
  menu.push :issue_statuses, {:controller => 'issue_statuses'}, :caption => :label_issue_status_plural,
            :html => {:class => 'issue_statuses'}
  menu.push :workflows, {:controller => 'workflows', :action => 'edit'}, :caption => :label_workflow
  menu.push :custom_fields, {:controller => 'custom_fields'},  :caption => :label_custom_field_plural,
            :html => {:class => 'custom_fields'}
  menu.push :enumerations, {:controller => 'enumerations'}
  menu.push :mokuais, {:controller => 'mokuais', :action => 'index'}, :caption => :field_mokuai_name #Mokuai
  menu.push :top_notices, {:controller => 'top_notices', :action => 'index'}, :caption => :field_top_notices #Top notices
  menu.push :approvals, {:controller => 'approvals', :action => 'index'}, :caption => :field_approvals #Top notices
  menu.push :templates, {:controller => 'templates'}
  menu.push :settings, {:controller => 'settings'}
  menu.push :ldap_authentication, {:controller => 'auth_sources', :action => 'index'},
            :html => {:class => 'server_authentication'}
  menu.push :plugins, {:controller => 'admin', :action => 'plugins'}, :last => true
  menu.push :info, {:controller => 'admin', :action => 'info'}, :caption => :label_information_plural, :last => true
end

Redmine::MenuManager.map :project_menu do |menu|
  menu.push :overview, { :controller => 'projects', :action => 'show' }
  menu.push :activity, { :controller => 'activities', :action => 'index' }
  menu.push :definitions, {:controller => 'definitions', :action => 'index' }, :param => :project_id,
            :caption => :label_definition, :permission => :view_definition
  menu.push :plans, '#', :param => :project_id, :caption => :label_plan, :permission => :view_plans,
            :children => Proc.new { |p| p.plan_modules.map{|m| Redmine::MenuManager::MenuItem.new("xx_#{m.id}".to_sym, "/projects/#{p.identifier}/plans?menuid=#{m.label}", :caption => m.name)} }
  menu.push :specs, { :controller => 'specs', :action => 'index' }, :param => :project_id, :caption => :label_specs,
            :permission => :view_specs
  menu.push :roadmap, { :controller => 'versions', :action => 'index' }, :param => :project_id
  # menu.push :issues, { :controller => 'issues', :action => 'index' }, :param => :project_id, :caption => :label_issue_plural
  menu.push :issues, '#', :param => :project_id, :caption => :label_issue_plural, :permission => :view_issue_to_merges,
            :children => Proc.new { |p| p.issue_manage_modules.map{|m| Redmine::MenuManager::MenuItem.new("xx_#{m.id}".to_sym, "/projects/#{p.identifier}/#{m.label}", :caption => m.name)} },
            :if => Proc.new { |p| !p.show_by(4) }
  menu.push :new_issue, { :controller => 'issues', :action => 'new', :copy_from => nil }, :param => :project_id, :caption => :label_issue_new,
              :html => { :accesskey => Redmine::AccessKeys.key_for(:new_issue) },
              :if => Proc.new { |p| Setting.new_project_issue_tab_enabled? && Issue.allowed_target_trackers(p).any? },
              :permission => :add_issues
  menu.push :gantt, { :controller => 'gantts', :action => 'show' }, :param => :project_id, :caption => :label_gantt
  menu.push :calendar, { :controller => 'calendars', :action => 'show' }, :param => :project_id, :caption => :label_calendar
  menu.push :news, { :controller => 'news', :action => 'index' }, :param => :project_id, :caption => :label_news_plural
  menu.push :documents, { :controller => 'documents', :action => 'index' }, :param => :project_id, :caption => :label_document_plural
  menu.push :wiki, { :controller => 'wiki', :action => 'index' }, :param => :project_id, :caption => :label_wiki
  menu.push :boards, { :controller => 'boards', :action => 'index', :id => nil }, :param => :project_id,
              :if => Proc.new { |p| p.boards.any? }, :caption => :label_board_plural
  menu.push :files, { :controller => 'files', :action => 'index' }, :caption => :label_file_plural, :param => :project_id
  menu.push :apk_bases, { :controller => 'apk_bases', :action => 'apks' }, :caption => :label_apk_base, :param => :project_id, :permission => :view_apk_bases,
            :if => Proc.new { |p| p.show_by(4) && p.production_type.in?([1, 4]) }
  menu.push :repository, { :controller => 'repositories', :action => 'show', :repository_id => nil, :path => nil, :rev => nil },
              :if => Proc.new { |p| p.repository && !p.repository.new_record? }
  menu.push :mokuai_ownners, { :controller => 'mokuai_ownners', :action => 'index' }, :param => :project_id, :caption => :label_mokuai_ownners,
              :permission => :view_mokuai_ownners, :if => Proc.new { |p| !p.show_by(4) }
  menu.push :members, { :controller => 'members', :action => 'members' }, :param => :project_id, :caption => :label_memberships_members
  menu.push :settings, { :controller => 'projects', :action => 'settings' }, :last => true
end

Redmine::Activity.map do |activity|
  activity.register :issues, :class_name => %w(Issue Journal)
  activity.register :changesets
  activity.register :news
  activity.register :documents, :class_name => %w(Document Attachment)
  activity.register :files, :class_name => 'Attachment'
  activity.register :wiki_edits, :class_name => 'WikiContent::Version', :default => false
  activity.register :messages, :default => false
  activity.register :time_entries, :default => false
end

Redmine::Search.map do |search|
  search.register :issues
  search.register :news
  search.register :documents
  search.register :changesets
  search.register :wiki_pages
  search.register :messages
  search.register :projects
end

Redmine::WikiFormatting.map do |format|
  format.register :textile
  format.register :markdown if Object.const_defined?(:Redcarpet)
end

ActionView::Template.register_template_handler :rsb, Redmine::Views::ApiTemplateHandler

# Amigo Global Permission

PolicyControl.map do |map|
  # project
  map.block :project do |map|
    map.permission :view_project, {:project => [:index?, :show?]}, :label => :permission_view_project
    map.permission :view_spec_list, {:spec => [:list?]}, :label => :permission_view_spec_list
    map.permission :view_project_progress, {:project_progress => [:index?]}, :label => :permission_view_project_progress
  end

  # production
  map.block :production do |map|
    map.permission :view_production, {:production => [:index?]}, :label => :permission_view_production
    map.permission :view_version_release, {:version_release => [:index?]}, :label => :permission_view_version_release
    map.permission :view_third_version_release, {:third_version_release => [:index?]}, :label => :permission_view_third_version_release
    map.permission :view_apk_base, {:apk_base => [:index?]}, :label => :permission_view_apk_base
    map.permission :view_app_members, {:production => [:members?]}, :label => :permission_view_app_members
    map.permission :view_app_records, {:production => [:records?]}, :label => :permission_view_app_records
    map.permission :edit_app_members, {:production => [:edit_info?, :update_info]}, :label => :permission_edit_app_members
    map.permission :mokuai_list, {:mokuai => [:list?, :history?, :edit_batch?, :sync_batch?]}, :label => :permission_mokuai_list
  end

  # map.block :issue do |map|
  #   map.permission :view_issue, {:issue => [:index?]}, :label => :permission_view_issue
  # end

  map.block :demand do |map|
    map.permission :view_demand, {:demand => [:index?, :show?]}, :label => :permission_view_demand
    map.permission :new_demand, {:demand => [:new?]}, :label => :permission_new_demand
  end

  map.block :repo_request do |map|
    map.permission :view_repo, {:repo => [:index?, :show?]}, :label => :permission_view_repo
    map.permission :view_project_branch, {:repo_request => [:index?]}, :label => :permission_view_project_branch
    map.permission :view_production_branch, {:repo_request => [:index?]}, :label => :permission_view_production_branch
    map.permission :view_production_repo, {:repo_request => [:index?]}, :label => :permission_view_production_repo
    map.permission :view_compile_machine_status, {:repo => [:compile_machine_status?]}, :label => :permission_view_compile_machine_status
    map.permission :view_version_jenkins, {:version => [:jenkins?]}, :label => :permission_view_version_jenkins
    map.permission :view_periodic_version, {:periodic_version => [:index?, :show?, :version_name_rules?]}, :label => :permission_view_periodic_version
    map.permission :view_version_app_infos, {:version => [:app_infos?]}, :label => :permission_view_version_app_infos
    map.permission :view_signature, {:signature => [:index?, :show?]}, :label => :permission_view_signature
    map.permission :new_signature, {:signature => [:new?, :create?]}, :label => :permission_new_signature
  end

  map.block :version_publish do |map|
    map.permission :view_version_publish, {:version_publish => [:view?]}, :label => :permission_view_version_publish
    map.permission :edit_version_publish, {:version_publish => [:edit?]}, :label => :permission_edit_version_publish
    map.permission :view_version_permission, {:version_permission => [:view?]}, :label => :permission_view_version_permission
    map.permission :edit_version_permission, {:version_permission => [:edit?]}, :label => :permission_edit_version_permission
    map.permission :view_native_applist, {:native_applist => [:view?]}, :label => :permission_view_native_applist
    map.permission :edit_native_applist, {:native_applist => [:edit?]}, :label => :permission_edit_native_applist
  end

  map.block :my do |map|
    map.permission :visit_links, {:my => [:links?]}, :label => :permission_visit_my_links
    map.permission :visit_staffs, {:my => [:staffs?]}, :label => :permission_visit_my_staffs
    map.permission :export_staffs, {:my => [:export?]}, :label => :permission_export_my_staffs
  end

  map.block :report do |map|
    map.permission :view_report, {:report => [:index?]}, :label => :permission_view_report
  end

  map.block :patch do |map|
    map.permission :view_patch, {:patch => [:index?, :show?]}, :label => :permission_view_patch
    map.permission :edit_patch, {:patch => [:new?, :create?]}, :label => :permission_edit_patch
  end

  map.block :sharing do |map|
    map.permission :view_google_tool, {:google_tool => [:index?]}, :label => :permission_view_google_tool
    map.permission :manage_google_tool, {:google_tool => [:category?, :new?, :create?, :edit?, :update?, :destroy?, :operate?]}, :label => :permission_manage_google_tool
    map.permission :view_tool, {:tool => [:index?]}, :label => :permission_view_tool
    map.permission :manage_tool, {:tool => [:new?, :create?, :edit?, :update?, :destroy?, :operate?]}, :label => :permission_manage_tool
  end

  map.block :process do |map|
    map.permission :view_flow_file, {:flow_file => [:index?, :show?]}, :label => :permission_view_flow_file
    map.permission :new_flow_file, {:flow_file => [:new?, :create?]}, :label => :permission_new_flow_file
    map.permission :edit_flow_file, {:flow_file => [:edit?, :update?]}, :label => :permission_edit_flow_file
    map.permission :manage_flow_file, {:flow_file => [:manage?]}, :label => :permission_manage_flow_file
    map.permission :destroy_flow_file, {:flow_file => [:destroy?]}, :label => :permission_destroy_flow_file
  end
end

