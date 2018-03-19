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

module QueriesHelper
  include ApplicationHelper
  require 'ruby-pinyin'

  def filters_options_for_select(query)
    ungrouped = []
    grouped = {}
    query.available_filters.map do |field, field_options|
      if [:tree, :relation].include?(field_options[:type])
        group = :label_relations
      elsif field =~ /^(.+)\./
        # association filters
        group = "field_#{$1}"
      elsif %w(member_of_group assigned_to_role dept_id).include?(field)
        group = :field_assigned_to
      elsif field_options[:type] == :date_past || field_options[:type] == :date
        group = :label_date
      elsif [:list_history].include?(field_options[:type])
        group = :label_history
      end
      if group
        (grouped[group] ||= []) << [field_options[:name], field]
      else
        ungrouped << [field_options[:name], field]
      end
    end
    # Don't group dates if there's only one (eg. time entries filters)
    if grouped[:label_date].try(:size) == 1
      ungrouped << grouped.delete(:label_date).first
    end

    # ungrouped << grouped.delete(:label_relations).first # Delete Ralation
    s = options_for_select((ungrouped))
    # s = options_for_select(([[]] + ungrouped).map{ |c| [c.first, c.second, { 'data-tokens' => PinYin.abbr(c.first)}] })
    # s = options_for_select((ungrouped).map{ |c| [c.first, c.second, { 'data-tokens' => PinYin.abbr(c.first)}] })
    if grouped.present?
      localized_grouped = grouped.map {|k,v| [l(k), v]}
      s << grouped_options_for_select(localized_grouped)
      # s << grouped_options_for_select(localized_grouped.map{ |group| [group.first, group.second.map{ |c| [c.first, c.second, { 'data-tokens' => PinYin.abbr(c.first)}] }] })
    end
    s
  end

  def query_filters_hidden_tags(query)
    tags = ''.html_safe
    query.filters.each do |field, options|
      tags << hidden_field_tag("f[]", field, :id => nil)
      tags << hidden_field_tag("op[#{field}]", options[:operator], :id => nil)
      options[:values].each do |value|
        tags << hidden_field_tag("v[#{field}][]", value, :id => nil)
      end
    end
    tags
  end

  def query_columns_hidden_tags(query)
    tags = ''.html_safe
    query.columns.each do |column|
      tags << hidden_field_tag("c[]", column.name, :id => nil)
    end
    tags
  end

  def query_hidden_tags(query)
    query_filters_hidden_tags(query) + query_columns_hidden_tags(query)
  end

  def available_block_columns_tags(query)
    tags = ''.html_safe
    query.available_block_columns.each do |column|
      tags << content_tag('label', check_box_tag('c[]', column.name.to_s, query.has_column?(column), :id => nil) + " #{column.caption}", :class => 'inline')
    end
    tags
  end

  def available_totalable_columns_tags(query)
    tags = ''.html_safe
    query.available_totalable_columns.each do |column|
      tags << content_tag('label', check_box_tag('t[]', column.name.to_s, query.totalable_columns.include?(column), :id => nil) + " #{column.caption}", :class => 'inline')
    end
    tags
  end

  def query_available_inline_columns_options(query)
    (query.available_inline_columns - query.columns).reject(&:frozen?).collect {|column| [column.caption, column.name]}
  end

  def query_selected_inline_columns_options(query)
    (query.inline_columns & query.available_inline_columns).reject(&:frozen?).collect {|column| [column.caption, column.name]}
  end

  def render_query_columns_selection(query, options={})
    tag_name = (options[:name] || 'c') + '[]'
    render :partial => 'queries/columns', :locals => {:query => query, :tag_name => tag_name}
  end

  def render_query_totals(query)
    return unless query.totalable_columns.present?
    totals = query.totalable_columns.map do |column|
      total_tag(column, query.total_for(column))
    end
    content_tag('p', totals.join(" ").html_safe, :class => "query-totals")
  end

  def total_tag(column, value)
    label = content_tag('span', "#{column.caption}:")
    value = content_tag('span', format_object(value), :class => 'value')
    content_tag('span', label + " " + value, :class => "total-for-#{column.name.to_s.dasherize}")
  end

  def column_header(column)
    column.sortable ? sort_header_tag(column.name.to_s, :caption => column.caption,
                                                        :default_order => column.default_order) :
                      content_tag('th', h(column.caption))
  end

  def column_content(column, issue)
    value = column.value_object(issue)
    if value.is_a?(Array)
      value.collect {|v| column_value(column, issue, v)}.compact.join(', ').html_safe
    else
      column_value(column, issue, value)
    end
  end

  def custom_priority_class(column, issue)
    "project_priority_highest" if column.value_object(issue).to_s == "P1-急需解决"
  end

  def column_value(column, issue, value)
    case column.name
    when :id
      link_to value, issue_path(issue)
    when :subject
      link_to value, issue_path(issue)
    when :parent
      value ? (value.visible? ? link_to_issue(value, :subject => false) : "##{value.id}") : ''
    when :description
      issue.description? ? content_tag('div', textilizable(issue, :description), :class => "wiki") : ''
    when :done_ratio
      progress_bar(value)
    when :relations
      content_tag('span',
        value.to_s(issue) {|other| link_to_issue(other, :subject => false, :tracker => false)}.html_safe,
        :class => value.css_classes_for(issue))
    when :mokuai_name
      issue.mokuai.present?? issue.mokuai.name : nil
    when :status_histories
      html = "<table class = 'table table-bordered'><tbody>"
      eval(value).each{|h| html <<  "<tr><td> #{h[:created_on]} </td><td> #{h[:status_name]} </td><td> #{h[:assigned_name]} </td><td> #{h[:user_name]} </td></tr>"}
      html << "</tbody></table>"
      html.html_safe
    else
      format_object(value)
    end
  end

  def csv_content(column, issue)
    value = column.value_object(issue)
    value = issue.mokuai.name if column.name == :mokuai_name && issue.mokuai.present? # Display Mokuai_name, not number
    if value.is_a?(Array)
      value.collect {|v| csv_value(column, issue, v)}.compact.join(', ')
    else
      csv_value(column, issue, value)
    end
  end

  def csv_value(column, object, value)
    format_object(value, false) do |value|
      case value.class.name
      when 'Float'
        sprintf("%.2f", value).gsub('.', l(:general_csv_decimal_separator))
      when 'IssueRelation'
        value.to_s(object)
      when 'Issue'
        if object.is_a?(TimeEntry)
          "#{value.tracker} ##{value.id}: #{value.subject}"
        else
          value.id
        end
      else
        value
      end
    end
  end

  def query_to_csv(items, query, options={})
    options ||= {}
    columns = (options[:columns] == 'all' ? query.available_inline_columns : query.inline_columns)
    query.available_block_columns.each do |column|
      if options[column.name].present?
        columns << column
      end
    end
    columns -=  query.hidden_columns # Remove hidden column when export

    csv_file = Redmine::Export::CSV.generate do |csv|
      # csv header fields
      csv << columns.map {|c| c.caption.to_s}
      # csv lines
      items.each do |item|
        csv << columns.map {|c| csv_content(c, item)}
      end
    end

    if options[:status_histories].present?
      csv_new = CSV.generate do |newcsv|
        CSV.parse(Redmine::CodesetUtil.to_utf8(csv_file, 'UTF-8'), :headers => true, :return_headers => true) do |row|
          if row.header_row?
            newcsv << row.fields + [l(:filed_issue_history_status_created_on), l(:field_status_histories), l(:field_assigned_histories), l(:filed_issue_status_by)]
          else
            eval(Issue.find(row.fields.first).status_histories).each do |h|
              newcsv << row.fields + [h[:created_on], h[:status_name], h[:assigned_name], h[:user_name]]
            end
          end
        end
      end
      Redmine::CodesetUtil.from_utf8(csv_new, 'UTF-8')
    else
      csv_file
    end

  end


  # Generate Excel xlsx

  def query_to_xlsx(items, query, options={})
    options ||= {}
    columns = (options[:columns] == 'all' ? query.available_inline_columns : query.inline_columns)
    query.available_block_columns.each do |column|
      if options[column.name].present?
        columns << column
      end
    end
    columns -=  query.hidden_columns # Remove hidden column when export

    # New xlsx
    package = Axlsx::Package.new
    workbook = package.workbook

    # Style
    styles = workbook.styles
    heading = styles.add_style :border => { :style => :thin, :color => "000000" }, b: true, sz: 12, bg_color: "F77609", fg_color: "FF"
    body = styles.add_style alignment: {horizontal: :left}, :border => { :style => :thin, :color => "000000" }

    # Workbook
    if options[:status_histories].blank?
      workbook.add_worksheet(name: "GIONEE") do |sheet|
        # Set subject width
        subject_index = columns.index{|c| c.name == :subject}
        heading_width = subject_index.present?? Array.new(subject_index, :auto).push(80) : []

        sheet.add_row (columns.map {|c| c.caption.to_s}), style: heading, widths: heading_width
        items.each_with_index do |item, index|
          sheet.add_row (columns.map {|c| csv_content(c, item)}), style: body
          sheet.add_hyperlink :location => issue_url(item), :ref => "A#{index + 2}"
        end
      end
    else
      # Generate csv file
      csv_file = Redmine::Export::CSV.generate do |csv|
        csv << columns.map {|c| c.caption.to_s}
        items.each{ |item| csv << columns.map {|c| csv_content(c, item)} }
      end

      workbook.add_worksheet(name: "GIONEE") do |sheet|
        histories_header = [l(:filed_issue_history_status_created_on), l(:field_status_histories), l(:field_assigned_histories), l(:filed_issue_status_by)]
        sheet.add_row (columns.map {|c| c.caption.to_s} + histories_header), style: heading
        # Reading csv file to generate xlsx file
        CSV.parse(Redmine::CodesetUtil.to_utf8(csv_file, 'UTF-8'), :headers => true, :return_headers => false) do |row|
          eval(Issue.find(row.fields.first).status_histories).each do |h|
            sheet.add_row row.fields + [h[:created_on], h[:status_name], h[:assigned_name], h[:user_name]], style: body
            sheet.add_hyperlink :location => issue_url(row.fields.first), :ref => "A#{sheet.rows.last.index + 1}" #sheet.rows.last.cells.first.r
          end
        end
      end
    end

    # package.to_stream.read
    package
  end



  # Retrieve query from session or build a new query
  def retrieve_query
    @condition_id = params[:condition_id] || ""
    @word         = params[:word]
    @preview      = params[:preview]
    @search       = params[:search]
    @caijue       = params[:caijue]

    # New Query
    @query = IssueQuery.new(:name => "_")

    ## Load Issue Condition
    if @condition_id.present?
      @condition = Condition.find(@condition_id)
      @issue_name = @condition.name
      @cond =  @condition.condition
      @query.column_names = @condition.column_order.split(",").map(&:to_sym) if @condition.column_order.present?
      User.current.add_condition_history(@condition_id) # Add to ConditionHistory
    elsif @search.present?
      @cond = @search || ""
      @query.column_names = params[:columns].split(",").map(&:to_sym) if params[:columns].present?
    elsif @caijue.present?
      @cond = ""
    else
      @cond = "(issues.project_id = #{@project.id})" if @project.present?
    end

    ## Just for quick search ID or Subject
    if @word.present?
      ids = @word.scan(/\d+/)
      user_ids = User.where("firstname LIKE ?", "%#{@word}%").pluck(:id).join(",")
      @cond.nil?? @cond = "(" : @cond << " AND ("
      @cond << " issues.id IN (#{ids.join(',')}) OR" if ids.present?
      @cond << " issues.assigned_to_id IN (#{user_ids}) OR" if user_ids.present?
      @cond << " issues.subject LIKE \"%#{@word}%\")"

      # Reoder if ids of word is present
      if ids.present? && !params[:sort]
        @issue_reorder = "FIELD(issues.id, #{ids.reverse*','}) DESC"
      end
    end

    # RequestStore.store[:current_issue_query] = @query

    if @preview.present?
      begin
        redis = Redis.new
        ids = redis.get(@preview)
      rescue => e
        logger.info("\nRedisError #{e}: (#{File.expand_path(__FILE__)})\n")
      end
      @cond.nil?? @cond = "(" : @cond << " AND ("

      if ids.present?
        @cond << " issues.id IN (#{ids}))"
        @issue_reorder = "FIELD(issues.id, #{ids.split(',').reverse*','}) DESC"
      end
    end

    @query.filters = {:condition => @cond, :is_html => (request.formats[0].symbol.to_s == "html")}
    @query.filters.merge!(:caijue => true) if @caijue == 'me'

    # if !params[:query_id].blank?
    #   cond = "project_id IS NULL"
    #   cond << " OR project_id = #{@project.id}" if @project
    #   @query = IssueQuery.where(cond).find(params[:query_id])
    #   raise ::Unauthorized unless @query.visible?
    #   @query.project = @project
    #   session[:query] = {:id => @query.id, :project_id => @query.project_id}
    #   sort_clear
    # elsif api_request? || params[:set_filter] || session[:query].nil? || session[:query][:project_id] != (@project ? @project.id : nil)
    #   # Give it a name, required to be valid
    #   @query = IssueQuery.new(:name => "_")
    #   @query.project = @project
    #   @query.build_from_params(params)
    #   session[:query] = {:project_id => @query.project_id, :filters => @query.filters, :group_by => @query.group_by, :column_names => @query.column_names, :totalable_names => @query.totalable_names}
    # else
    #   # retrieve from session
    #   @query = nil
    #   @query = IssueQuery.find_by_id(session[:query][:id]) if session[:query][:id]
    #   @query ||= IssueQuery.new(
    #                             :name => "_",
    #                             :filters => session[:query][:filters],
    #                             :group_by => session[:query][:group_by],
    #                             # :column_names => session[:query][:column_names],
    #                             :totalable_names => session[:query][:totalable_names]
    #                            )
    #   @query.project = @project
    # end
  end

  def retrieve_query_from_session
    if session[:query]
      if session[:query][:id]
        @query = IssueQuery.find_by_id(session[:query][:id])
        return unless @query
      else
        @query = IssueQuery.new(:name => "_", :filters => session[:query][:filters], :group_by => session[:query][:group_by], :column_names => session[:query][:column_names], :totalable_names => session[:query][:totalable_names])
      end
      if session[:query].has_key?(:project_id)
        @query.project_id = session[:query][:project_id]
      else
        @query.project = @project
      end
      @query
    end
  end

  # Returns the query definitions as hidden field tags
  def query_as_hidden_field_tags(query)
    tags = hidden_field_tag("set_filter", "1", :id => nil)

    # if query.filters.present?
    #   query.filters.each do |field, filter|
    #     tags << hidden_field_tag("f[]", field, :id => nil)
    #     tags << hidden_field_tag("op[#{field}]", filter[:operator], :id => nil)
    #     filter[:values].each do |value|
    #       tags << hidden_field_tag("v[#{field}][]", value, :id => nil)
    #     end
    #   end
    # end
    if query.column_names.present?
      query.column_names.each do |name|
        tags << hidden_field_tag("c[]", name, :id => nil)
      end
    end
    if query.totalable_names.present?
      query.totalable_names.each do |name|
        tags << hidden_field_tag("t[]", name, :id => nil)
      end
    end
    if query.group_by.present?
      tags << hidden_field_tag("group_by", query.group_by, :id => nil)
    end

    tags
  end
end
