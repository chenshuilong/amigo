# encoding: utf-8
#
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

module ProjectsHelper

  def project_settings_tabs
    tabs = [{:name => 'info', :action => :edit_project, :partial => 'projects/edit', :label => :label_information_plural},
            {:name => 'modules', :action => :select_project_modules, :partial => 'projects/settings/modules', :label => :label_module_plural},
            #{:name => 'members', :action => :manage_members, :partial => 'projects/settings/members', :label => :label_member_plural},
            {:name => 'versions', :action => :manage_versions, :partial => 'projects/settings/versions', :label => :label_version_plural},
            {:name => 'categories', :action => :manage_categories, :partial => 'projects/settings/issue_categories', :label => :label_issue_category_plural},
            {:name => 'wiki', :action => :manage_wiki, :partial => 'projects/settings/wiki', :label => :label_wiki},
            {:name => 'repositories', :action => :manage_repository, :partial => 'projects/settings/repositories', :label => :label_repository_plural},
            {:name => 'boards', :action => :manage_boards, :partial => 'projects/settings/boards', :label => :label_board_plural},
            {:name => 'activities', :action => :manage_project_activities, :partial => 'projects/settings/activities', :label => :enumeration_activities}
            ]
    tabs.select {|tab| User.current.allowed_to?(tab[:action], @project)}
  end

  def parent_project_select_tag(project)
    selected = project.parent
    # retrieve the requested parent project
    parent_id = (params[:project] && params[:project][:parent_id]) || params[:parent_id]
    if parent_id
      selected = (parent_id.blank? ? nil : Project.find(parent_id))
    end

    options = ''
    options << "<option value=''>&nbsp;</option>" if project.allowed_parents.include?(nil)
    options_projects = project.allowed_parents.compact
    if project.present?
      if project.show_by(4)
        options_projects = options_projects.find_all{|p| p.production_type.to_i == project.production_type.to_i}
      else
        options_projects = options_projects.find_all{|p| p.category.to_i == project.category.to_i}
      end
    end
    options << project_tree_options_for_select(project.allowed_parents.compact, :selected => selected)
    content_tag('select', options.html_safe, :name => 'project[parent_id]', :id => 'project_parent_id')
  end

  def render_project_action_links
    links = []
    if User.current.allowed_to?(:add_project, nil, :global => true)
      links << link_to(l(:label_project_new), new_project_path, :class => 'icon icon-add')
    end
    if User.current.allowed_to?(:view_issues, nil, :global => true)
      links << link_to(l(:label_issue_view_all), issues_path)
    end
    # if User.current.allowed_to?(:view_time_entries, nil, :global => true)
    #   links << link_to(l(:label_overall_spent_time), time_entries_path)
    # end
    # links << link_to(l(:label_overall_activity), activity_path)
    links.join(" | ").html_safe
  end

  # Renders the projects index
  def render_project_hierarchy(projects)
    render_project_nested_lists(projects) do |project|
      s = link_to_project_with_external_name(project, {}, :class => "#{project.css_classes} #{User.current.member_of?(project) ? 'my-project' : nil}")
      if project.description.present?
        s << content_tag('div', textilizable(project.short_description, :project => project), :class => 'wiki description')
      end
      s
    end
  end

  # Returns a set of options for a select field, grouped by project.
  def version_options_for_select(versions, selected=nil)
    grouped = Hash.new {|h,k| h[k] = []}
    versions.each do |version|
      grouped[version.project.name] << [version.name, version.id]
    end

    selected = selected.is_a?(Version) ? selected.id : selected
    if grouped.keys.size > 1
      grouped_options_for_select(grouped, selected)
    else
      options_for_select((grouped.values.first || []), selected)
    end
  end

  def project_default_version_options(project)
    versions = project.shared_versions.open.to_a
    if project.default_version && !versions.include?(project.default_version)
      versions << project.default_version
    end
    version_options_for_select(versions, project.default_version)
  end

  def format_version_sharing(sharing)
    sharing = 'none' unless Version::VERSION_SHARINGS.include?(sharing)
    l("label_version_sharing_#{sharing}")
  end

  def render_boards_tree(boards, parent=nil, level=0, &block)
    selection = boards.select {|b| b.parent == parent}
    return '' if selection.empty?

    s = ''.html_safe
    selection.each do |board|
      node = capture(board, level, &block)
      node << render_boards_tree(boards, board, level+1, &block)
      s << content_tag('div', node)
    end
    content_tag('div', s, :class => 'sort-level')
  end

  def render_api_includes(project, api)
    api.array :trackers do
      project.trackers.each do |tracker|
        api.tracker(:id => tracker.id, :name => tracker.name)
      end
    end if include_in_api_response?('trackers')

    api.array :issue_categories do
      project.issue_categories.each do |category|
        api.issue_category(:id => category.id, :name => category.name)
      end
    end if include_in_api_response?('issue_categories')

    api.array :enabled_modules do
      project.enabled_modules.each do |enabled_module|
        api.enabled_module(:id => enabled_module.id, :name => enabled_module.name)
      end
    end if include_in_api_response?('enabled_modules')

  end

  def load_exist_date(project, column)
    if project.id.present? && project.send(column).present?
      content_tag :small, :class => "form-text text-muted" do
        "已有时间：" + project.send(column).join(", ")
      end
    end
  end

  def productions_menu_list
    productions = policy(:production).view_all? ? Production.active : User.current.productions

    productions = productions.where(:production_type => @type) if @type
    productions.group_by(&:production_type).map { |type, productions|
      pd_type = Project::PROJECT_PRODUCTION_TYPE.find { |t, v| v == type }.first
      pd_text = l("project_production_type_#{pd_type}".to_sym)
      {:text => "#{pd_text}(#{productions.size})", :href => "/productions?type=#{type}", :tooltip => pd_text, :isFolder => true, :isExpanded => true,
       :children => productions.map { |pd|
         {:text => pd.name, :href => project_path(pd), :tooltip => pd.name}
       }
      }
    }
  end

  def production_submenu_by_type(production_type)
    javascript_tag "$('#tab-productions').empty().append('#{production_submenu_lists(production_type)}');"
  end

  def production_submenu_lists(production_type)
    production_menulists.select { |menu|
      menu[:type] == production_type.to_i
    }.map { |menu| content_tag :ul do
      menu[:lis].unshift({:name => "汇总", :href => productions_path}).map { |li|
        li[:href] == void_js || li[:href] == "#" ? (content_tag :li, class: "comingsoon" do
          li[:name]
        end) : (content_tag :li, class: li[:actived] ? "active" : "" do
          link_to li[:name], li[:href]
        end)
      }.join.html_safe
    end }.join.html_safe
  end

  def production_menulists
    [{:type => 1, :lis => [{:name => l(:project_production_type_app), :href => "/productions?type=1", :actived => true}]},
     {:type => 2, :lis => [{:name => l(:project_production_type_modem), :href => "/productions?type=2", :actived => true}]},
     {:type => 3, :lis => [{:name => l(:project_production_type_framework), :href => "/productions?type=3", :actived => true}]},
     {:type => 4, :lis => [{:name => l(:project_production_type_preload), :href => "/productions?type=4", :actived => true},
                           {:name => l(:project_production_type_3rd_version_release), :href => '/thirdparty_version_releases?cate=1'}]},
     {:type => 5, :lis => [{:name => l(:project_production_type_jar), :href => "/productions?type=5", :actived => true},
                           {:name => l(:project_production_type_sdk_version_release), :href => '/sdk_version_releases'}]},
     {:type => 6, :lis => [{:name => l(:project_production_type_resource), :href => "/productions?type=6", :actived => true},
                           {:name => l(:project_production_type_resource_version_release), :href => '/thirdparty_version_releases?cate=2'}]},
     {:type => 7, :lis => [{:name => l(:project_production_type_widget), :href => "/productions?type=7", :actived => true}]},
     {:type => 8, :lis => [{:name => l(:project_production_type_management), :href => "/productions?type=8", :actived => true}]},
     {:type => 9, :lis => [{:name => l(:project_production_type_other), :href => "/productions?type=9", :actived => true}]}]
  end

  def identifier_description
    %(
      <p style='color:red;'>标识代表项目软件编码，该字段在项目间不允许重名；规则如下：</p>
      <ol>
        <li>深研O平台项目，标识填写为SWP + 内部型号，示例：O平台内部型号为1802A的深研项目，标识填写为SWP1802A；</li>
        <li>深研N平台项目，标识填写为SW + 内部型号，示例：N平台内部型号为17G01A的项目，标识填写为SW17G01A；</li>
        <li>北研O平台项目，标识填写为BJP + 内部型号，示例：O平台内部型号为1808A的北研项目，标识填写为BJP1808A；</li>
        <li>北研N平台项目，标识填写为BJ + 内部型号，示例：N平台内部型号为17G08A的深研项目，标识填写为BJ17G08A；</li>
        <li>项目量产后新建OTA项目，标识填写为：该项目在研项目标识+_OTA+_8位日期，示例：SWP1802A_OTA_20180401；</li>
        <li>项目量产后新建内测项目，标识填写为：该项目在研项目标识+_Autotest，示例：SW17G01A_Autotest；</li>
      </ol>
     )
  end
end
