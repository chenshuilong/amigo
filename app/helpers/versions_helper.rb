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

module VersionsHelper
  include ReposHelper

  def version_anchor(version)
    if @project == version.project
      anchor version.name
    else
      anchor "#{version.project.try(:identifier)}-#{version.name}"
    end
  end

  def version_filtered_issues_path(version, options = {})
    options = {:fixed_version_id => version, :set_filter => 1}.merge(options)
    project = case version.sharing
      when 'hierarchy', 'tree'
        if version.project && version.project.root.visible?
          version.project.root
        else
          version.project
        end
      when 'system'
        nil
      else
        version.project
    end

    if project
      project_issues_path(project, options)
    else
      issues_path(options)
    end
  end

  STATUS_BY_CRITERIAS = %w(tracker status priority author assigned_to category)

  def render_issue_status_by(version, criteria)
    criteria = 'tracker' unless STATUS_BY_CRITERIAS.include?(criteria)

    h = Hash.new {|k,v| k[v] = [0, 0]}
    begin
      # Total issue count
      version.fixed_issues.group(criteria).count.each {|c,s| h[c][0] = s}
      # Open issues count
      version.fixed_issues.open.group(criteria).count.each {|c,s| h[c][1] = s}
    rescue ActiveRecord::RecordNotFound
    # When grouping by an association, Rails throws this exception if there's no result (bug)
    end
    # Sort with nil keys in last position
    counts = h.keys.sort {|a,b| a.nil? ? 1 : (b.nil? ? -1 : a <=> b)}.collect {|k| {:group => k, :total => h[k][0], :open => h[k][1], :closed => (h[k][0] - h[k][1])}}
    max = counts.collect {|c| c[:total]}.max

    render :partial => 'issue_counts', :locals => {:version => version, :criteria => criteria, :counts => counts, :max => max}
  end

  def status_by_options_for_select(value)
    options_for_select(STATUS_BY_CRITERIAS.collect {|criteria| [l("field_#{criteria}".to_sym), criteria]}, value)
  end

  def avaliable_status_of_versions(version)
    statuses = Version::VERSION_STATUS

    if version.as_increase_version
      valid = []
      %w(reserved released google_approved).each do |state|
        valid << [l("version_status_#{state}"), statuses[state.to_sym]]
      end
      valid
    elsif version.status != statuses[:deleted]
      (statuses.except(:deleted)).collect {|s| [l("version_status_#{s.first}"), s.last]}
    else
      [l(:version_status_deleted), statuses[:deleted]]
    end
  end

  def compile_status_class(version)
    status = version.class.const_get :VERSION_COMPILE_STATUS
    case version.compile_status
      when status[:failed] then 'text-danger'
      when status[:successful] then 'text-success'
      when status[:stoped] then 'text-muted'
    end
  end

  def specs_options_for_select(project)
    specs = project.specs.undeleted
    return [] if specs.empty?
    values = specs.map do |spec|
      default_mark = "(#{l(:version_default_spec)})" if spec.is_default?
      [spec.name + default_mark.to_s, spec.id]
    end
    options_for_select(values, params[:version].try(:[], :spec_id) || @version.try(:spec_id))
  end

  def render_safe_html_content(version)
    path = params[:filepath] || "coverage"
    path =  "_#{path}" if path.match(/\//)
    path = File.join(version.utr_final_directory, "#{path}.html")
    if File.exist?(path)
      page = Nokogiri::HTML(open(path))
      page.css("a").each { |link| link['href'] = link['href'].gsub(/_|.html/, '') }
      page.encoding = 'UTF-8'
      page.at('body').inner_html.html_safe
    else
      l(:label_no_data)
    end
  end

  def load_unit_test_value
    if @version.has_unit_test_report?
      load_value(@version, :unit_test) + "&nbsp;&nbsp;" +
      link_to("(#{l(:version_unit_test_report)})", unit_test_report_version_path(@version, :trailing_slash => true))
    else
      load_value(@version, :unit_test)
    end.html_safe
  end

  def mail_receiver_options
    if @version.mail_receivers.present?
      users = User.where(:id => @version.mail_receivers)
      options_from_collection_for_select(users, :id, :name, @version.mail_receivers)
    else
      {}
    end
  end

  def unit_test_project_options
    projects = Api::Version.unit_test_projects
    if @version.auto_test_projects.present?
      options_for_select(projects, @version.auto_test_projects)
    else
      projects
    end
  end

  def way_to_download_smb
    %(
      <ul>
        <li>Windows<BR>#{l :version_windows_download_smb}</li>
        <li>Linux<BR>#{l :version_linux_download_smb}</li>
      </ul>
     )
  end

  def all_increase_versions(version)
    versions = version.all_increase_versions
    versions.select('versions.id, specs.name spec_name, versions.name').to_a.group_by(&:spec_name).to_json
  end

  def link_to_version_compare(app)
    if app[:app_version_ids].split(",").count == 2
      version_ids = app[:app_version_ids].split(",")
      url = compare_versions_path(category: "other", version_ida: version_ids[0], version_idb: version_ids[1], type: 'app')
      result = content_tag(:span, (link_to '比较',  url, class: 'text-primary'))
    else
      result = '<span class="text-disabled">比较</span>'.html_safe
    end
  end

  def time_zone_value(timezone)
    if timezone.to_i > 0
      content = l("version_timezone_east_#{timezone}".to_sym)
    elsif timezone.to_i < 0
      content = l("version_timezone_west_#{timezone}".to_sym)
    else
      content = '-'
    end
    return content
  end

  def releases_ids(v)
    content = []
    v.releases.each do |r|
      content << link_to(r.id, version_release_path(r))
    end
    return content.join(',').html_safe
  end

  def releases_projects(v)
    content = []
    v.releases.where(category: [1,2], status: [5]).each do |r|
      value = r.tested_mobile
      if value.size == value.scan(/\d+/).sum(&:size) + value.count(',')
        ids = value.scan(/\d+/)
        content << Project.where(:id => ids).pluck(:name)
      else
        content << value
      end
    end
    return content.join("、")
  end
end
