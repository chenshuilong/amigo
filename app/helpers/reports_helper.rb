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

module ReportsHelper
  include IssuesHelper

  def aggregate(data, criteria)
    a = 0
    data.each { |row|
      match = 1
      criteria.each { |k, v|
        match = 0 unless (row[k].to_s == v.to_s) || (k == 'closed' &&  (v == 0 ? ['f', false] : ['t', true]).include?(row[k]))
      } unless criteria.nil?
      a = a + row["total"].to_i if match == 1
    } unless data.nil?
    a
  end

  def aggregate_link(data, criteria, *args)
    a = aggregate data, criteria
    a > 0 ? link_to(h(a), *args) : '-'
  end

  def aggregate_path(project, field, row, options={})
    parameters = {:set_filter => 1, :subproject_id => '!*', field => row.id}.merge(options)
    project_issues_path(row.is_a?(Project) ? row : project, parameters)
  end

  def show_issue_solved_table(data,columns)
    rows = "<thead><tr>"
    columns = columns.nil? ? {:no => "排名",:assigoedname => "姓名",:orgNm => "部门",:solved_times => "解决时长"} : columns
    columns.each_value do |k|
      rows <<  "<th>#{k}</th>"
    end

    rows << "</tr></thead><tbody>"

    data.each_with_index do |row,index|
      rows << "<tr><td>#{index + 1}</td><td>#{row.assigoedname}</td><td>#{row.orgNm}</td><td>#{row.solved_times}</td></tr>"
    end
    rows << "</tbody>"
    rows.html_safe
  end

  def condition_report_star_list
    condition_report_list User.current.conditions.report_star.root
  end

  def condition_report_system_list
    condition_report_list Condition.report_system.root
  end

  def condition_report_history_list
    return "" unless User.current.logged?
    history = User.current.report_condition_histories.first(10) # Latest 10 record
    if history.present?
      content_tag :ul do
        history.map do |h|
          concat content_tag(:li, link_to(h.condition.name.gsub('/',''), "javascript:;", target: h.from_id))
        end
      end
    else
      ""
    end
  end

  def condition_report_list(root)
    return "" unless User.current.logged?
    if root.present?
      parse_root(root)
    else
      ""
    end.gsub('&lt;', "<").gsub('&gt;', '>')
  end

  def personalize_menu_list
    [{"id" => "100", "text" => "质量报表", "tooltip" => "质量报表", "isFolder" => true, "isExpanded" => true,
      "children" => [{
                         "id" => "100.100",
                         "text" => "SQA定制",
                         "isFolder" => true, "isExpanded" => true,
                         "children" => [{
                                            "id" => "bug_analysis_timeout",
                                            "text" => "研发分析超时BUG数",
                                            "href" => "/reports/personalize?menuid=bug_analysis_timeout",
                                            "tooltip" => "已解状态的BUG中,分配到已修复的时长超过10天的BUG中,某责任人转入到转出的时间超过3天的BUG数"
                                        },
                                        {
                                            "id" => "leave_amount_and_solved_rate",
                                            "text" => "遗留BUG数及解决率",
                                            "href" => "/reports/personalize?menuid=leave_amount_and_solved_rate",
                                            "tooltip" => "显示某个项目截止到当前时间的BUG未解数,已解数,解决率与标准的差值等"
                                        },
                                        {
                                            "id" => "leave_amount_rank_by_dept",
                                            "text" => "遗留BUG TOP10部门分布",
                                            "href" => "/reports/personalize?menuid=leave_amount_rank_by_dept",
                                            "tooltip" => "以项目为单位,遗留BUG中,按部门排列TOP10,并显示每个部门相应的BUG解决率"
                                        },
                                        {
                                            "id" => "leave_amount_rank_by_mokuai",
                                            "text" => "遗留BUG TOP10模块分布",
                                            "href" => "/reports/personalize?menuid=leave_amount_rank_by_mokuai",
                                            "tooltip" => "以项目为单位,遗留BUG中,按模块排列TOP10"
                                        },
                                        {
                                            "id" => "leave_amount_rank_by_issue_category",
                                            "text" => "遗留BUG TOP10问题分类分布",
                                            "href" => "/reports/personalize?menuid=leave_amount_rank_by_issue_category",
                                            "tooltip" => "以项目为单位,遗留BUG中,按问题分类排列TOP10"
                                        },
                                        {
                                            "id" => "leave_amount_group_by_owner_and_rom",
                                            "text" => "各属性中遗留BUG各责任人分布（ROM）",
                                            "href" => "/reports/personalize?menuid=leave_amount_group_by_owner_and_rom",
                                            "tooltip" => "以项目为单位，遗留BUG中，按属性分类，每个属性的BUG中按照责任人分布"
                                        },
                                        # {
                                        #     "id" => "leave_amount_group_by_reason_and_owner",
                                        #     "text" => "各Reason中遗留BUG各责任人分布",
                                        #     "href" => "/reports/personalize?menuid=leave_amount_group_by_reason_and_owner",
                                        #     "tooltip" => "以项目为单位,遗留BUG中,按Reason分类,每个Reason的BUG中按照责任人分布"
                                        # },
                                        {
                                            "id" => "timeout_and_unhandle_bug_coverage",
                                            "text" => "超时未处理BUG状况",
                                            "href" => "/reports/personalize?menuid=timeout_and_unhandle_bug_coverage",
                                            "tooltip" => "以项目为单位,遗留BUG中,按Reason分类,每个Reason的BUG中按照责任人分布"
                                        },
                                        {
                                            "id" => "bug_moving_time",
                                            "text" => "bug走查",
                                            "href" => "/reports/personalize?menuid=bug_moving_time",
                                            "tooltip" => "bug状态改变时的时间(从历史状态中查找某个状态改变的历史时间)"
                                        },
                                        {
                                            "id" => "bug_verificating_time",
                                            "text" => "bug验证时长",
                                            "href" => "/reports/personalize?menuid=bug_verificating_time",
                                            "tooltip" => "bug验证时长"
                                        },
                                        {
                                            "id" => "bug_moving_and_back_to_owner",
                                            "text" => "bug流转走查",
                                            "href" => "/reports/personalize?menuid=bug_moving_and_back_to_owner",
                                            "tooltip" => "不经分析就转回原来的责任人"
                                        }]
                     }]},
     {"id" => "101", "text" => "项目报表", "tooltip" => "项目报表", "isFolder" => true, "isExpanded" => true},
     {"id" => "102", "text" => "运营指标", "tooltip" => "运营指标", "isFolder" => true, "isExpanded" => true,
      "children" => [{
                         "id" => "102.100", "isFolder" => true, "isExpanded" => true,
                         "text" => "质量指标",
                         "tooltip" => "质量指标",
                         "children" => [{
                                            "id" => "leave_times_and_rate",
                                            "text" => "遗留数量及遗留率",
                                            "href" => "/reports/personalize?menuid=leave_times_and_rate",
                                            "tooltip" => "遗留数量及遗留率"
                                        }]
                     }]
     }]
  end

  def filter_one_options_for_select
    # Project::PROJECT_CATEGORY -- 项目类型
    "<option value=\"roles\">角色</option>\n
     <option value=\"priority_id\">严重等级</option>\n
     <option value=\"cf_2\">概率</option>\n
     <option value=\"project_id\">项目</option>\n
     <option value=\"project_category\">项目类型</option>\n
     <option value=\"project_hard_category\">项目难度分类</option>\n
     <option value=\"flow\">流</option>\n".html_safe
  end

  def user_options(condition)
    users = condition.possible_users
    users.map do |user|
      content_tag :option, :value => user.id do
        user.name
      end
    end.join.html_safe
  end
end
