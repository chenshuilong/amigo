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

Rails.application.routes.draw do

  require 'sidekiq/web'
  mount Sidekiq::Web => '/background/tasks'

  root :to => 'my#index', :as => 'home'

  get 'welcome', :to => 'welcome#index'
  match 'login', :to => 'account#login', :as => 'signin', :via => [:get, :post]
  match 'logout', :to => 'account#logout', :as => 'signout', :via => [:get, :post]

  match 'versions/specs', :to => 'versions#specs', :via => :get #versions manage
  # match 'account/register', :to => 'account#register', :via => [:get, :post], :as => 'register'
  match 'account/lost_password', :to => 'account#lost_password', :via => [:get, :post], :as => 'lost_password'
  match 'account/activate', :to => 'account#activate', :via => :get
  get 'account/activation_email', :to => 'account#activation_email', :as => 'activation_email'

  match '/news/preview', :controller => 'previews', :action => 'news', :as => 'preview_news', :via => [:get, :post, :put, :patch]
  match '/issues/preview/new/:project_id', :to => 'previews#issue', :as => 'preview_new_issue', :via => [:get, :post, :put, :patch]
  match '/issues/preview/edit/:id', :to => 'previews#issue', :as => 'preview_edit_issue', :via => [:get, :post, :put, :patch]
  match '/issues/preview', :to => 'previews#issue', :as => 'preview_issue', :via => [:get, :post, :put, :patch]

  match 'projects/:id/wiki', :to => 'wikis#edit', :via => :post
  match 'projects/:id/wiki/destroy', :to => 'wikis#destroy', :via => [:get, :post]

  match 'boards/:board_id/topics/new', :to => 'messages#new', :via => [:get, :post], :as => 'new_board_message'
  get 'boards/:board_id/topics/:id', :to => 'messages#show', :as => 'board_message'
  match 'boards/:board_id/topics/quote/:id', :to => 'messages#quote', :via => [:get, :post]
  get 'boards/:board_id/topics/:id/edit', :to => 'messages#edit'

  post 'boards/:board_id/topics/preview', :to => 'messages#preview', :as => 'preview_board_message'
  post 'boards/:board_id/topics/:id/replies', :to => 'messages#reply'
  post 'boards/:board_id/topics/:id/edit', :to => 'messages#edit'
  post 'boards/:board_id/topics/:id/destroy', :to => 'messages#destroy'

  # Misc issue routes. TODO: move into resources
  match '/issues/auto_complete', :to => 'auto_completes#issues', :via => :get, :as => 'auto_complete_issues'
  match '/issues/context_menu', :to => 'context_menus#issues', :as => 'issues_context_menu', :via => [:get, :post]
  match '/issues/changes', :to => 'journals#index', :as => 'issue_changes', :via => :get
  match '/issues/:id/quoted', :to => 'journals#new', :id => /\d+/, :via => :post, :as => 'quoted_issue'

  resources :journals, :only => [:edit, :update] do
    member do
      get 'diff'
    end
  end

  get '/projects/:project_id/issues/gantt', :to => 'gantts#show', :as => 'project_gantt'
  get '/issues/gantt', :to => 'gantts#show'

  get '/projects/:project_id/issues/calendar', :to => 'calendars#show', :as => 'project_calendar'
  get '/issues/calendar', :to => 'calendars#show'

  get 'projects/:id/issues/report', :to => 'reports#issue_report', :as => 'project_issues_report'
  get 'projects/:id/issues/report/:detail', :to => 'reports#issue_report_details', :as => 'project_issues_report_details'

  get   '/issues/imports/new', :to => 'imports#new', :as => 'new_issues_import'

  post  '/imports', :to => 'imports#create', :as => 'imports'
  get   '/imports/:id', :to => 'imports#show', :as => 'import'
  match '/imports/:id/settings', :to => 'imports#settings', :via => [:get, :post], :as => 'import_settings'
  match '/imports/:id/mapping', :to => 'imports#mapping', :via => [:get, :post], :as => 'import_mapping'
  match '/imports/:id/run', :to => 'imports#run', :via => [:get, :post], :as => 'import_run'

  get 'reports', :to => 'reports#index', :as => 'report_index'
  get 'reports/all_users', :to => 'reports#all_users'
  get 'reports/more', :to => 'reports#more', :as => 'report_more'
  get 'reports/display', :to => 'reports#display', :as => 'report_display'
  post 'reports/display_reports',:to => 'reports#display_report_by_type'
  post 'reports/preview',:to => 'reports#preview'
  get 'reports/personalize',:to => 'reports#personalize', :as => 'personalization'
  post 'reports/personalize',:to => 'reports#personalize'
  get 'reports/export',:to => 'reports#export'
  get 'reports/personalize_export_data',:to => 'reports#personalize_export_data'

  post 'my/avatar', :controller => 'my', :action => 'update_avatar'
  match 'my/account(/:tab)', :controller => 'my', :action => 'account', :as => 'my_account', :via => [:get, :post]
  match 'my/account/destroy', :controller => 'my', :action => 'destroy', :via => [:post]
  match 'my/page', :controller => 'my', :action => 'page', :via => :get
  match 'my', :controller => 'my', :action => 'index', :via => :get # Redirects to my/page
  get 'my/api_key', :to => 'my#show_api_key', :as => 'my_api_key'
  post 'my/api_key', :to => 'my#reset_api_key'
  post 'my/rss_key', :to => 'my#reset_rss_key', :as => 'my_rss_key'
  match 'my/password', :controller => 'my', :action => 'password', :via => [:get, :post]
  match 'my/page_layout', :controller => 'my', :action => 'page_layout', :via => :get
  match 'my/add_block', :controller => 'my', :action => 'add_block', :via => :post
  match 'my/remove_block', :controller => 'my', :action => 'remove_block', :via => :post
  match 'my/order_blocks', :controller => 'my', :action => 'order_blocks', :via => :post
  match 'my/links', :controller => 'my', :action => 'links', :via => :get # Links: Neiwangjuhe
  match 'my/staffs', :controller => 'my', :action => 'staffs', :via => :get # Staffs: Find people
  match 'my/export_staffs', :controller => 'my', :action => 'export_staffs', :via => :post # Staffs: Find people
  match 'my/notifications', :controller => 'notifications', :action => 'index', :via => :get
  match 'my/notifications/:id/handle', :to => 'notifications#handle', :as => "handle_notification", :via => :post
  match 'my/tasks', :controller => 'my', :action => 'tasks', :via => :get

  resources :users do
    resources :memberships, :controller => 'principal_memberships'
    resources :email_addresses, :only => [:index, :create, :update, :destroy]
    collection do
      get 'import' => 'users#import'
      post 'import_csv' => 'users#import_csv'
      match 'uaam' => 'users#uaam', :via => [:get, :post]
      get 'search' => 'users#search'
      get 'assigned' => 'users#assigned'
    end
  end

  post 'watchers/watch', :to => 'watchers#watch', :as => 'watch'
  delete 'watchers/watch', :to => 'watchers#unwatch'
  get 'watchers/new', :to => 'watchers#new', :as => 'new_watchers'
  post 'watchers', :to => 'watchers#create'
  post 'watchers/append', :to => 'watchers#append'
  delete 'watchers', :to => 'watchers#destroy'
  get 'watchers/autocomplete_for_user', :to => 'watchers#autocomplete_for_user'
  # Specific routes for issue watchers API
  post 'issues/:object_id/watchers', :to => 'watchers#create', :object_type => 'issue'
  delete 'issues/:object_id/watchers/:user_id' => 'watchers#destroy', :object_type => 'issue'

  resources :projects do

    member do
      get 'settings(/:tab)', :action => 'settings', :as => 'settings'
      post 'modules'
      post 'archive'
      post 'unarchive'
      post 'close'
      post 'reopen'
      match 'copy', :via => [:get, :post]
    end

    shallow do
      resources :memberships, :controller => 'members', :only => [:index, :show, :new, :create, :update, :destroy] do
        collection do
          get 'autocomplete'
          get 'users'
          get 'members'
          get 'roles'
        end

        member do 
          get 'group_members'
        end
      end
    end

    resource :enumerations, :controller => 'project_enumerations', :only => [:update, :destroy]

    get 'issues/:copy_from/copy', :to => 'issues#new', :as => 'copy_issue'
    resources :issues, :only => [:index, :new, :create]
    # Used when updating the form of a new issue
    post 'issues/new', :to => 'issues#new'

    resources :files, :only => [:index, :new, :create]

    resources :versions, :except => [:index, :show, :edit, :update, :destroy] do
      collection do
        put 'close_completed'
        get 'generate_name'
        # get 'ota_increase_versions'
      end
    end
    get 'versions.:format', :to => 'versions#index'
    get 'roadmap', :to => 'versions#index', :format => false
    get 'versions', :to => 'versions#index'

    resources :news, :except => [:show, :edit, :update, :destroy]
    resources :time_entries, :controller => 'timelog', :except => [:show, :edit, :update, :destroy] do
      get 'report', :on => :collection
    end
    resources :queries, :only => [:new, :create]
    shallow do
      resources :issue_categories
    end
    resources :documents, :except => [:show, :edit, :update, :destroy] do
      collection do
        put 'new_version'
        post 'upload'
      end
    end
    resources :boards
    shallow do
      resources :repositories, :except => [:index, :show] do
        member do
          match 'committers', :via => [:get, :post]
        end
      end
    end

    match 'wiki/index', :controller => 'wiki', :action => 'index', :via => :get
    resources :wiki, :except => [:index, :create], :as => 'wiki_page' do
      member do
        get 'rename'
        post 'rename'
        get 'history'
        get 'diff'
        match 'preview', :via => [:post, :put, :patch]
        post 'protect'
        post 'add_attachment'
      end
      collection do
        get 'export'
        get 'date_index'
        post 'new'
      end
    end
    match 'wiki', :controller => 'wiki', :action => 'show', :via => :get
    get 'wiki/:id/:version', :to => 'wiki#show', :constraints => {:version => /\d+/}
    delete 'wiki/:id/:version', :to => 'wiki#destroy_version'
    get 'wiki/:id/:version/annotate', :to => 'wiki#annotate'
    get 'wiki/:id/:version/diff', :to => 'wiki#diff'

    resources :mokuai_ownners do
      collection do
        post 'fetch'
        post 'copy'
        get 'reverse'
      end
    end

    ## Spec
    resources :specs do
      collection do
        post "collct"
        post "lock"
        post "freeze"
        post "copy"
        post "reset"
        post "frost"
        post "editapp"
        post "udapp"
        post "delapp"
        post "alter_records"
        get "export"
        get "export_apps"
        get "get_app_versions"
        get "get_project_specs"
        get "get_spec_main_versions"
        get "get_parent_and_children_spec_version"
      end
    end

    ## Product Definition
    resources :definitions do
      collection do
        post 'create_custom_field'
        post 'edit_custom_field'
        post 'create_definition_module'
        post 'edit_definition_module'
        post 'create_module_field'
        post 'edit_module_field'
        post 'delete_module_field'
        post 'create_custom_value'
        post 'edit_custom_value'
        post 'create_compare_model'
        post 'delete_compare_model'
        post 'delete_custom_value'
        post 'edit_definition_module'
        post 'definition_custom_values'
        post 'definition_modules'
        post 'definition_custom_fields'
        post 'definition_module_fields'
        post 'definition_compare_model'
        post 'hide_definition_module'
        post 'copy'
      end
    end

    ## Project Plan
    resources :plans do
      collection do
        post 'get_data'
        post 'lock'
        post 'quick_sort'
      end
    end

    ## Project Timeline
    resources :timelines do
      collection do
        post "branch_points"
      end
    end

    ## Issue to approve or merge
    resources :issue_to_approve_merges do
      collection do
        post "send_task"
      end
    end
    resources :issue_to_approves
    resources :issue_to_merges

    resources :issue_to_special_tests
    resources :issue_to_special_test_results

    resources :apk_bases, :except => [:index, :show]
    get 'apks', :to => 'apk_bases#apks', :format => false
    get 'apk_bases', :to => 'apk_bases#apks'
    get 'search', :to => 'projects#search', :on => :collection
  end

  # Load Member Change Form
  get "/memberships/:id/fetch", :to => "members#fetch", :as => "fetch_membership"

  resources :issues do
    member do
      # Used when updating the form of an existing issue
      patch 'edit', :to => 'issues#edit'
      get 'breifly', :to => 'issues#breifly'
    end
    collection do
      match 'bulk_edit', :via => [:get, :post]
      match 'gerrit', :via => [:get, :post]
      post 'bulk_update'
      post 'batch', :to => 'issues#batch'
    end
    resources :time_entries, :controller => 'timelog', :except => [:show, :edit, :update, :destroy] do
      collection do
        get 'report'
      end
    end
    shallow do
      resources :relations, :controller => 'issue_relations', :only => [:index, :show, :create, :destroy]
    end
  end
  # Used when updating the form of a new issue outside a project
  post '/issues/new', :to => 'issues#new'
  post '/projects/new', :to => 'projects#new'
  match '/issues', :controller => 'issues', :action => 'destroy', :via => :delete
  match '/issues/:id/statuses_history', :to => 'issues#statuses_history', :via => :post

  resources :queries, :except => [:show]

  resources :news, :only => [:index, :show, :edit, :update, :destroy]
  match '/news/:id/comments', :to => 'comments#create', :via => :post
  match '/news/:id/comments/:comment_id', :to => 'comments#destroy', :via => :delete

  resources :versions, :only => [:show, :edit, :update, :destroy] do
    post 'status_by', :on => :member
    post 'change', :on => :member
    post 'stop_compiling', :on => :member
    post 'unit_test_report/upload', :to => 'versions#upload_unit_test_report', :on => :member
    get 'unit_test_report(/*filepath)', :to => 'versions#unit_test_report', :as => 'unit_test_report', :on => :member
    get 'search_repo_info', :on => :member
    get 'search', :to => "versions#search", :as => 'search', :on => :collection
    get 'choose', :to => "versions#choose", :on => :collection
    get 'compare', :to => "versions#compare", :on => :collection
    get 'app_infos', :to => "versions#app_infos", :on => :collection
  end
  match 'versions', :to => "versions#jenkins", :as => 'all_versions', :via => :get

  resources :documents, :only => [:show, :edit, :update, :destroy] do
    post 'add_attachment', :on => :member
  end

  match '/time_entries/context_menu', :to => 'context_menus#time_entries', :as => :time_entries_context_menu, :via => [:get, :post]

  resources :time_entries, :controller => 'timelog', :except => :destroy do
    collection do
      get 'report'
      get 'bulk_edit'
      post 'bulk_update'
    end
  end
  match '/time_entries/:id', :to => 'timelog#destroy', :via => :delete, :id => /\d+/
  # TODO: delete /time_entries for bulk deletion
  match '/time_entries/destroy', :to => 'timelog#destroy', :via => :delete
  # Used to update the new time entry form
  post '/time_entries/new', :to => 'timelog#new'

  get 'projects/:id/activity', :to => 'activities#index', :as => :project_activity
  get 'activity', :to => 'activities#index'


  # repositories routes
  get 'projects/:id/repository/:repository_id/statistics', :to => 'repositories#stats'
  get 'projects/:id/repository/:repository_id/graph', :to => 'repositories#graph'

  get 'projects/:id/repository/:repository_id/changes(/*path)',
      :to => 'repositories#changes',
      :format => false

  get 'projects/:id/repository/:repository_id/revisions/:rev', :to => 'repositories#revision'
  get 'projects/:id/repository/:repository_id/revision', :to => 'repositories#revision'
  post   'projects/:id/repository/:repository_id/revisions/:rev/issues', :to => 'repositories#add_related_issue'
  delete 'projects/:id/repository/:repository_id/revisions/:rev/issues/:issue_id', :to => 'repositories#remove_related_issue'
  get 'projects/:id/repository/:repository_id/revisions', :to => 'repositories#revisions'
  get 'projects/:id/repository/:repository_id/revisions/:rev/:action(/*path)',
      :controller => 'repositories',
      :format => false,
      :constraints => {
            :action => /(browse|show|entry|raw|annotate|diff)/,
            :rev    => /[a-z0-9\.\-_]+/
          }

  get 'projects/:id/repository/statistics', :to => 'repositories#stats'
  get 'projects/:id/repository/graph', :to => 'repositories#graph'

  get 'projects/:id/repository/changes(/*path)',
      :to => 'repositories#changes',
      :format => false

  get 'projects/:id/repository/revisions', :to => 'repositories#revisions'
  get 'projects/:id/repository/revisions/:rev', :to => 'repositories#revision'
  get 'projects/:id/repository/revision', :to => 'repositories#revision'
  post   'projects/:id/repository/revisions/:rev/issues', :to => 'repositories#add_related_issue'
  delete 'projects/:id/repository/revisions/:rev/issues/:issue_id', :to => 'repositories#remove_related_issue'
  get 'projects/:id/repository/revisions/:rev/:action(/*path)',
      :controller => 'repositories',
      :format => false,
      :constraints => {
            :action => /(browse|show|entry|raw|annotate|diff)/,
            :rev    => /[a-z0-9\.\-_]+/
          }
  get 'projects/:id/repository/:repository_id/:action(/*path)',
      :controller => 'repositories',
      :action => /(browse|show|entry|raw|changes|annotate|diff)/,
      :format => false
  get 'projects/:id/repository/:action(/*path)',
      :controller => 'repositories',
      :action => /(browse|show|entry|raw|changes|annotate|diff)/,
      :format => false

  get 'projects/:id/repository/:repository_id', :to => 'repositories#show', :path => nil
  get 'projects/:id/repository', :to => 'repositories#show', :path => nil

  # additional routes for having the file name at the end of url
  get 'attachments/:id/:filename', :to => 'attachments#show', :id => /\d+/, :filename => /.*/, :as => 'named_attachment'
  get 'attachments/download/:id/:filename', :to => 'attachments#download', :id => /\d+/, :filename => /.*/, :as => 'download_named_attachment'
  get 'attachments/download/:id', :to => 'attachments#download', :id => /\d+/
  get 'attachments/thumbnail/:id(/:size)', :to => 'attachments#thumbnail', :id => /\d+/, :size => /\d+/, :as => 'thumbnail'
  resources :attachments, :only => [:show, :destroy]
  get 'attachments/:object_type/:object_id/edit', :to => 'attachments#edit', :as => :object_attachments_edit
  patch 'attachments/:object_type/:object_id', :to => 'attachments#update', :as => :object_attachments

  resources :groups do
    resources :memberships, :controller => 'principal_memberships'
    member do
      get 'autocomplete_for_user'
      post 'import'
    end
  end

  get 'groups/:id/users/new', :to => 'groups#new_users', :id => /\d+/, :as => 'new_group_users'
  post 'groups/:id/users', :to => 'groups#add_users', :id => /\d+/, :as => 'group_users'
  delete 'groups/:id/users/:user_id', :to => 'groups#remove_user', :id => /\d+/, :as => 'group_user'

  resources :trackers, :except => :show do
    collection do
      match 'fields', :via => [:get, :post]
    end
  end
  resources :issue_statuses, :except => :show do
    collection do
      post 'update_issue_done_ratio'
    end
  end
  resources :custom_fields, :except => :show do
    resources :enumerations, :controller => 'custom_field_enumerations', :except => [:show, :new, :edit]
    put 'enumerations', :to => 'custom_field_enumerations#update_each'
  end
  resources :roles do
    collection do
      match 'permissions', :via => [:get, :post]
    end
  end
  resources :enumerations, :except => :show
  match 'enumerations/:type', :to => 'enumerations#index', :via => :get
  match 'enumerations/search_children', :to => 'enumerations#search_children', :via => :post

  get 'projects/:id/search', :controller => 'search', :action => 'index'
  get 'projects/:id/check_same_custom_value', :to => 'projects#same_custome_value'
  get 'search', :controller => 'search', :action => 'index'

  get  'mail_handler', :to => 'mail_handler#new'
  post 'mail_handler', :to => 'mail_handler#index'

  get 'admin', :to => 'admin#index'
  get 'admin/projects', :to => 'admin#projects'
  get 'admin/plugins', :to => 'admin#plugins'
  get 'admin/info', :to => 'admin#info'
  post 'admin/test_email', :to => 'admin#test_email', :as => 'test_email'
  post 'admin/default_configuration', :to => 'admin#default_configuration'

  resources :auth_sources do
    member do
      get 'test_connection', :as => 'try_connection'
    end
    collection do
      get 'autocomplete_for_new_user'
    end
  end

  match 'workflows', :controller => 'workflows', :action => 'index', :via => :get
  match 'workflows/edit', :controller => 'workflows', :action => 'edit', :via => [:get, :post]
  match 'workflows/permissions', :controller => 'workflows', :action => 'permissions', :via => [:get, :post]
  match 'workflows/copy', :controller => 'workflows', :action => 'copy', :via => [:get, :post]
  match 'settings', :controller => 'settings', :action => 'index', :via => :get
  match 'settings/edit', :controller => 'settings', :action => 'edit', :via => [:get, :post]
  match 'settings/plugin/:id', :controller => 'settings', :action => 'plugin', :via => [:get, :post], :as => 'plugin_settings'

  match 'sys/projects', :to => 'sys#projects', :via => :get
  match 'sys/projects/:id/repository', :to => 'sys#create_project_repository', :via => :post
  match 'sys/fetch_changesets', :to => 'sys#fetch_changesets', :via => [:get, :post]

  match 'uploads', :to => 'attachments#upload', :via => :post

  get 'robots.txt', :to => 'welcome#robots'
  get 'login/ad', :to => 'welcome#loginAd'

  resources :default_values, :only => [:create, :update, :destroy] do
    member do
      get 'load', :to => 'default_values#load', :as => 'load'
    end
  end

  resources :conditions, :only => [:create, :update, :destroy] do
    collection do
      get 'conditionvalue'
      get 'conditioncolumn'
      get 'conditioninfo'
      post 'conditionshare', :as => "share"
    end
  end

  ## Mokuai

  resources :mokuais do 
    get 'list', on: :collection
    get 'edit_batch', on: :member
    post 'sync_batch', on: :member
    get 'history', on: :member
  end

  ## Production
  match 'productions', :controller => 'productions', :action => 'index', :via => :get
  match 'productions/new', :to => "productions#new", :via => :get, :as => "new_productions"
  match 'productions/members', :to => "productions#members", :via => :get, :as => "app_members"
  match 'productions/:id/edit_info', :to => 'productions#edit_info', :via => :get, :as => 'edit_info_production'
  match 'productions/:id/update_info', :to => 'productions#update_info', :via => :post, :as => 'update_info_production'
  match 'productions/records', :to => 'productions#records', :via => :get, :as => 'app_records'

  ## Api
  match 'api/version', :controller => 'api', :action => 'version', :via => :get
  match 'api/issue_history_status', :controller => 'api', :action => 'issue_history_status', :via => :get
  match 'api/depts_tree', :controller => 'api', :action => 'depts_tree', :via => [:get, :post]
  match 'api/dept_users', :controller => 'api', :action => 'dept_users', :via => :get
  match 'api/xianxiang', :controller => 'api', :action => 'xianxiang', :via => :get
  match 'api/user', :controller => 'api', :action => 'user', :via => :get
  match 'api/beiyan_version', :controller => 'api', :action => 'beiyan_version', :via => :get
  match 'api/virtual_version', :controller => 'api', :action => 'virtual_version', :via => :get
  match 'api/gradle_version', :controller => 'api', :action => 'gradle_version', :via => :post

  ## Help
  match 'help', :to => "qandas#index", :via => :get
  scope :help do
    # root "qandas#index"
    resources :qandas #QandA
    resources :new_features #New Feature
  end

  ## Top notice
  resources :top_notices, only: [:index, :new, :create]

  ## Aprroval
  resources :approvals

  ## Repo
  resources :repos do
    get 'compile_machine_status', on: :collection
    collection do
      get 'link', :to => 'repos#getlink'
      post 'link', :to => 'repos#link'
      post 'unlink', :to => 'repos#unlink'
      post 'freeze', :to => 'repos#freeze'
    end
  end

  ## Version Release
  resources :version_releases do
    post 'new', on: :collection, as: 'new_version_release'
    post 'rerelease', on: :member
    get 'version_lists', on: :collection
    get 'version_apks', on: :collection
    get 'logs/:md5', :to => "version_releases#view_log", :as => "view_log", on: :member
    match 'reset_problem', on: :member, via: [:get, :post]
  end

  ## Third party Version Release
  resources :thirdparty_version_releases do
    get 'logs/:md5', :to => "thirdparty_version_releases#view_log", :as => "view_log", on: :member

    collection do
      post 'upload'
      post 'reupload'
      post 'release'
    end
  end

  ## SDK Version Release
  resources :sdk_version_releases do
    get 'logs/:md5', :to => "sdk_version_releases#view_log", :as => "view_log", on: :member

    collection do
      post 'upload'
      post 'reupload'
      post 'release'
    end
  end

  ## Definition Modules
  resources :definition_sections
  get 'projects/:project_id/definition_sections/:id', :to => 'definitions#module_show', :as => 'definition_section_project'
  get 'projects/:project_id/plans/:id', :to => 'plans#index', :as => 'plan_project'

  ## Periodic Version
  resources :periodic_versions, :except => :destroy do
    post 'new', on: :collection, as: 'new_periodic_version'
    post 'close', on: :member
    collection do
      get 'rules', to: 'periodic_versions#version_name_rules'
      match 'rules/new', to: 'periodic_versions#new_version_name_rule', via: [:get, :post]
      match 'rules/:id/edit', as: 'rule_edit', to: 'periodic_versions#edit_version_name_rule', via: [:get, :post]
    end
    post 'get_rules_by_platform', on: :collection
  end

  #specs list, compare, export function in project
  match 'specs', :to => 'specs#list', :via => :get
  match 'specs/compare', :to => 'specs#compare', :via => :get
  match 'specs/update_specs', :to => 'specs#update_specs', :via => :get
  match 'specs/export_compare_specs', :to => 'specs#export_compare_specs', :via => :get

  # send task in project's plan
  post 'projects/:project_id/plans/:id/send_task', :to => 'plans#send_task'
  resources :tasks do
    get 'special_test_task', on: :member
    get 'edit_special_test_task', on: :member
    post 'issue_to_special_test_task', on: :collection
    post 'issue_to_task', on: :collection
    post 'edit_task', on: :collection
    match 'update_special_test_task', on: :member, via: [:post, :patch, :put]
    post 'personal_task', on: :collection
    get 'personal_task_new', on: :collection
    get 'personal_task_edit', on: :member
    match 'personal_task_create', on: :collection, via: [:post]
    match 'personal_task_update', on: :member, via: [:post, :patch, :put]
    post 'apk_base_task', on: :collection
    get 'apk_base_task_edit', on: :member
    match 'apk_base_task_update', on: :member, via: [:post, :patch, :put]
    post 'patch_version_task', on: :collection
    get 'patch_version_task_edit', on: :member
    match 'patch_version_task_update', on: :member, via: [:post, :patch, :put]
    post 'library_file_task', on: :collection
    get 'library_file_task_edit', on: :member
    match 'library_file_task_update', on: :member, via: [:post, :patch, :put]
    post 'library_update_task', on: :collection
    get 'library_update_task_edit', on: :member
    match 'library_update_task_update', on: :member, via: [:post, :patch, :put]
    post 'library_merge_task', on: :collection
    get 'library_merge_task_edit', on: :member
    match 'library_merge_task_update', on: :member, via: [:post, :patch, :put]
  end
  match '/tasks/:id/handle', :to => 'tasks#handle', :as => "handle_task", :via => :post

  resources :version_publishes do
    member do
      get :publish
      get :export
      get :abnormal_report
    end
    collection do
      get :preview
      get :add_app
      get :search_spec_version
      get :refresh
      post :save_change
      get :history
    end
  end

  resources :version_permissions do
    collection do
      post :change
      post :save_change
    end
  end

  resources :faster_new, :only => [:index] do
    collection do
      FasterNewController::MENU_INFO.keys.each do |i|
        get i
      end
    end
  end


  resources :repo_requests, except: [:index] do
    member do 
      get :abandon
    end
    collection do
      get :search_projects
      get :search_versions
      post :issue_to_approve_merges
    end
  end
  match '/:category/repo_requests', :controller => 'repo_requests', :action => 'index', :via => :get, :as => "repo_requests/index"

  # creterions
  resources :criterions, :except => [:new, :create] do
    collection do
      get :report
      get :backend
    end
  end

  # exports
  resources :exports,  :except => [:new, :create, :show, :update] do
    get :download, on: :member
  end

  #repo_request permission
  resources :custom_permissions do
    member do
      get :do_lock
    end
  end

  #File Upload copy from attachment
  resources :upload_files, :only => [:show, :destroy]
  get 'upload_files/:id/:filename', :to => 'upload_files#show', :id => /\d+/, :filename => /.*/, :as => "named_upload_files"
  get 'upload_files/download/:id/:filename', :to => 'upload_files#download', :id => /\d+/, :filename => /.*/, :as => 'download_named_upload_files'
  get 'upload_files/download/:id', :to => 'upload_files#download', :id => /\d+/

  # resourcing - global permission
  resources :resourcings do
    match :edit_permission, on: :collection, via: [:get, :post]
  end

  resources :demands

  resources :native_applists do 
    match :history, on: :collection, via: :get
  end

  resources :apk_bases do 
    collection do 
      get :history
      get :search
    end
  end

  resources :templates
  resources :depts

  resources :view_records, :except => [:index, :new, :edit, :show, :create, :update, :destroy] do 
    collection do 
      get :lists
    end
  end

  resources :patches, :only => [:index, :new, :create, :show] do 
    post :infos, :on => :member
    post :jenkins_url, :on => :member
    get :generate_patchno, :on => :collection
    get :files, :on => :collection
    get :search_spec, :on => :collection
    get :conflict_files, :on => :collection
  end

  get 'patches/export_conflict_files/:id', :to => 'patches#export_conflict_files', :id => /\d+/

  # beijing ftp log
  get '/ftp_log', :to => 'ftp_log#index'

  # 项目进度汇总
  get '/project_progress', :to => 'project_progress#index'

  resources :signatures, :only => [:index, :new, :create, :show] do 
    post :change, :on => :member
  end

  resources :google_tools do 
    get :category, :on => :collection
    get :operate, :on => :collection
  end

  resources :tools do 
    get :operate, :on => :collection
  end

  Dir.glob File.expand_path("plugins/*", Rails.root) do |plugin_dir|
    file = File.join(plugin_dir, "config/routes.rb")
    if File.exists?(file)
      begin
        instance_eval File.read(file)
      rescue Exception => e
        puts "An error occurred while loading the routes definitions of #{File.basename(plugin_dir)} plugin (#{file}): #{e.message}."
        exit 1
      end
    end
  end
end
