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

class ReportsController < ApplicationController
  menu_item :issues

  before_action :check_user_if_outsource
  before_filter :find_project, :authorize, :find_issue_statuses, :only => [:issue_report, :issue_report_details]

  helper :queries
  include QueriesHelper
  include IssuesHelper
  helper :sort
  include SortHelper

  NO_PAGNATION_REPORTS =
      ["bug分析时长", "平均未解决时长", "已解的重分配数量", "平均解决时长", "bug数量",
       "平均已解的重分配数量", "平均未走读时长", "平均未验证时长", "重打开率",
       "平均关闭时长", "平均走读时长", "平均验证时长", "分配准确率", "重分配率"]
  WITH_USER_REPORTS = ["发现bug数量"]

  def index
    auth :report
    # unless User.current.allowed_to?(:view_reports, [], :global => true)
    #   raise ::Unauthorized
    # end
    @projects = Project.sorted.where("category in (#{Project::PROJECT_CATEGORY.values[0, 3].join(',')})")

    @depts = Dept.options_group_for_select
    @users = User.where("status = 1 and orgNo in ('#{Dept::AVAIS.map { |d| Dept.find_by_orgNo(d).all_down_depts }.flatten.uniq.join('\',\'')}')").select("id,firstname").collect { |user| "<option value=\"#{user.id}\">#{user.firstname}</option>" }
    @project_categories = Project::PROJECT_CATEGORY.keys.map { |p| "<option value=\"#{Project::PROJECT_CATEGORY[p]}\">#{p}</option>" }

    retrieve_query

    redirect_to :action => "display", :condition_id => params[:condition_id] if params[:condition_id]
  end

  def display
    if params[:condition_id].nil? || Condition.find(params[:condition_id]).blank?
      redirect_to :action => "index"
    end

    @depts = Dept.options_group_for_select
    @users = User.where("status = 1 and orgNo in ('#{Dept::AVAIS.map { |d| Dept.find_by_orgNo(d).all_down_depts }.flatten.uniq.join('\',\'')}')").select("id,firstname").collect { |user| "<option value=\"#{user.id}\">#{user.firstname}</option>" }
    @projects = Project.sorted.collect { |p| "<option value=\"#{p.id}\">#{p.name}</option>" }
    @project_categories = Project::PROJECT_CATEGORY.keys.map { |p| "<option value=\"#{Project::PROJECT_CATEGORY[p]}\">#{p}</option>" }

    @condition = Condition.find(params[:condition_id])
    retrieve_query

    @report_issues = get_data_by_condition
    #generate_sql Condition.find(params[:condition_id]).condition
    #@report_issues = JournalDetail.find_by_sql(group_and_limit_report_data(true,"assigoedname","AVG(solved_time_sconds)",nil))
    User.current.add_report_condition_history(params[:condition_id])

  rescue => e
    # redirect_to :action => "index"
  end

  def more
    index

    @report_name = report_name
    @report_issues = JournalDetail.find_by_sql(group_and_limit_report_data(true, "assigoedname", "solved_times DESC", nil))
  end

  def preview
    cur_page = params[:cur_page] || 1
    per_page = params[:per_page] || Report::PER_PAGE
    offset = (cur_page.to_i - 1)*per_page.to_i
    limit = per_page

    pages = generate_pagination({:total => get_body_from_data.to_a.length, :per_page => params[:per_page] || Report::PER_PAGE, :cur_page => params[:cur_page] || 1})
    objs = NO_PAGNATION_REPORTS.include?(params[:reporttype]) ? get_body_from_data[offset.to_i, limit.to_i] : get_body_from_data.offset(offset).limit(limit)
    rows = generate_table({:thead => get_head_from_columns, :tbody => generate_body(objs)})

    render :text => {:status => 1, :table => rows << pages, :rows => get_body_from_data, :days => params[:dwm_yn].to_i == 1 ? count_start_to_end_days : nil, :message => "success!"}.to_json
      # render :text => {:table => Issue.bug_amount(",#{handle_params_select.join(',')}",nil,nil,nil,nil).to_sql,:message => "success!"}.to_json
  rescue => e
    render_error :message => e.to_s
    # render :text => {:status => 0, :table => nil, :message => "Error,#{e.to_s}"}.to_json
  end

  def personalize
    @depts = Dept.options_group_for_select
    @users = User.where("status = 1 and orgNo in ('#{Dept::AVAIS.map { |d| Dept.find_by_orgNo(d).all_down_depts }.flatten.uniq.join('\',\'')}')").select("id,firstname").collect { |user| "<option value=\"#{user.id}\">#{user.firstname}</option>" }
    @projects = Project.sorted.collect { |p| "<option value=\"#{p.id}\">#{p.name}</option>" }
    @project_categories = Project::PROJECT_CATEGORY.keys.map { |p| "<option value=\"#{Project::PROJECT_CATEGORY[p]}\">#{p}</option>" }

    if request.xhr?
      days = count_start_to_end_days
      @rows =
          case params[:menuid]
            when "bug_moving_time" then
              raise "开始时间或者结束时间不能为空" if params[:start_dt].empty? || params[:end_dt].empty?
              sql = ["issues.by_tester = 1"]

              sql << "issues.project_id in (#{params[:project_ids]})" if params[:project_ids] && params[:project_ids].to_s != "null"
              sql << "depts.id in (#{params[:assigned_dept_ids]})" if params[:assigned_dept_ids] && params[:assigned_dept_ids].to_s != "null"
              Issue.bug_moving_time(params[:start_dt] || 'start_dt', params[:end_dt] || 'end_dt', params[:status_ids], params[:assigned_to_ids], sql.join(' and '))
            # JournalDetail.bug_moving_time(sql.join(' and '), nil, nil, params[:status_ids])
            when "leave_times_and_rate" then
              day_feilds = []
              days.each do |day|
                case params[:dwm]
                  when "day" then
                    day_feilds << "SUM(CASE WHEN (DATE_FORMAT(SUBSTRING_INDEX(iss.times,',',1),'%Y%m%d') = '#{day}' AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss.times,',',1),NOW()) > #{params[:days].to_i*3600*24}) OR (DATE_FORMAT(SUBSTRING_INDEX(iss.times,',',2),'%Y%m%d') = '#{day}' AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss.times,',',2),NOW()) > #{params[:days].to_i*3600*24}) OR (DATE_FORMAT(SUBSTRING_INDEX(iss.times,',',3),'%Y%m%d') = '#{day}' AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss.times,',',3),NOW()) > #{params[:days].to_i*3600*24}) THEN 1 ELSE 0 END) AS d_#{day}"
                  # day_feilds << "SUM(CASE WHEN (DATE_FORMAT(SUBSTRING_INDEX(iss.times,',',1),'%Y%m%d') = '#{day}' AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss.times,',',1),NOW()) > #{params[:days].to_i*3600*24}) OR (DATE_FORMAT(SUBSTRING_INDEX(iss.times,',',2),'%Y%m%d') = '#{day}' AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss.times,',',2),NOW()) > #{params[:days].to_i*3600*24}) OR (DATE_FORMAT(SUBSTRING_INDEX(iss.times,',',3),'%Y%m%d') = '#{day}' AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss.times,',',3),NOW()) > #{params[:days].to_i*3600*24}) THEN 1 ELSE 0 END)/assigned.amount AS l_#{day}"
                  when "week" then
                    day_feilds << "SUM(CASE WHEN (WEEKOFYEAR(SUBSTRING_INDEX(iss.times,',',1)) = '#{day}' AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss.times,',',1),NOW()) > #{params[:days].to_i*3600*24}) OR (WEEKOFYEAR(SUBSTRING_INDEX(iss.times,',',2)) = '#{day}' AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss.times,',',2),NOW()) > #{params[:days].to_i*3600*24}) OR (WEEKOFYEAR(SUBSTRING_INDEX(iss.times,',',3)) = '#{day}' AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss.times,',',3),NOW()) > #{params[:days].to_i*3600*24}) THEN 1 ELSE 0 END) AS d_#{day}"
                  # day_feilds << "SUM(CASE WHEN (WEEKOFYEAR(SUBSTRING_INDEX(iss.times,',',1)) = '#{day}' AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss.times,',',1),NOW()) > #{params[:days].to_i*3600*24}) OR (WEEKOFYEAR(SUBSTRING_INDEX(iss.times,',',2)) = '#{day}' AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss.times,',',2),NOW()) > #{params[:days].to_i*3600*24}) OR (WEEKOFYEAR(SUBSTRING_INDEX(iss.times,',',3)) = '#{day}' AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss.times,',',3),NOW()) > #{params[:days].to_i*3600*24}) THEN 1 ELSE 0 END)/assigned.amount AS l_#{day}"
                  when "month" then
                    day_feilds << "SUM(CASE WHEN (DATE_FORMAT(SUBSTRING_INDEX(iss.times,',',1),'%Y%m') = '#{day}' AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss.times,',',1),NOW()) > #{params[:days].to_i*3600*24}) OR (DATE_FORMAT(SUBSTRING_INDEX(iss.times,',',2),'%Y%m') = '#{day}' AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss.times,',',2),NOW()) > #{params[:days].to_i*3600*24}) OR (DATE_FORMAT(SUBSTRING_INDEX(iss.times,',',3),'%Y%m') = '#{day}' AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss.times,',',3),NOW()) > #{params[:days].to_i*3600*24}) THEN 1 ELSE 0 END) AS d_#{day}"
                  # day_feilds << "SUM(CASE WHEN (DATE_FORMAT(SUBSTRING_INDEX(iss.times,',',1),'%Y%m') = '#{day}' AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss.times,',',1),NOW()) > #{params[:days].to_i*3600*24}) OR (DATE_FORMAT(SUBSTRING_INDEX(iss.times,',',2),'%Y%m') = '#{day}' AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss.times,',',2),NOW()) > #{params[:days].to_i*3600*24}) OR (DATE_FORMAT(SUBSTRING_INDEX(iss.times,',',3),'%Y%m') = '#{day}' AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss.times,',',3),NOW()) > #{params[:days].to_i*3600*24}) THEN 1 ELSE 0 END)/assigned.amount AS l_#{day}"
                end
              end
              handle_params_where << "issues.status_id in (#{IssueStatus::LEAVE_STATUS})"
              table = Issue.leave_times_and_rate(handle_params_where.join(' and '), "issues.id", "journals.created_on,issues.id").to_sql
              Issue.find_by_sql("select username,deptname,categoryname,assigned_to_id,assigned.amount,#{day_feilds.join(',')} from (#{table}) as iss
            left join (
              SELECT COUNT(id) AS amount,CASE WHEN issues.assigned_to_id IS NULL THEN 0 ELSE issues.assigned_to_id END AS uid FROM issues
              GROUP BY issues.assigned_to_id) AS assigned ON  iss.assigned_to_id = assigned.uid GROUP BY iss.assigned_to_id")
            # Issue.find_by_sql(Report::Personalize.leave_times_and_rate_sql(sql))
            when "bug_analysis_timeout" then
              nbugs = []
              bugs = []
              sumBug = 0
              bugids = []
              Issue.find_by_sql(Issue.analysis_timeout(handle_params_where.join(' and '), nil)).group_by(&:iid).each do |iss, journals|
                (1..journals.size - 1).each do |i|
                  bugs << journals[i-1] if journals[i].created_on - journals[i-1].created_on > 3*24*3600 && journals[i].jusername.to_s == journals[i-1].username.to_s
                  # if journals[i].created_on - journals[i-1].created_on > 3*24*3600 && journals[i].jusername.to_s == journals[i-1].username.to_s
                  #   compare_time = []
                  #   Journal.with_between_time(journals[i-1].created_on,journals[i].created_on).each do |journal|
                  #     # juser = User.find(journal.user_id)
                  #     if journal.orgNm == journals[i-1].deptname # || (juser.dept && juser.dept.manager_id && juser.dept.manager_id == journals[i-1].juser_id)
                  #       (1..journal.details.size - 1).each do |j|
                  #         if !(journal.details[j].prop_key.to_s == "status_id" && (IssueStatus::UNSOLVED_STATUS + "," + IssueStatus::ANALYSIS_STATUS + "," + IssueStatus::REPAIRED_STATUS).include?(journal.details[j].value.to_s))
                  #           compare_time << journal.created_on
                  #           bugs << {:iid => journals[i-1].iid,:deptname => journal.orgNm,
                  #                    :username => journal.username,:jusername => journal.username,
                  #                    :juser_id => journal.user_id,:created_on => journal.created_on,
                  #                    :mon => format_date(journal.created_on).to_s.gsub('-','')} if journal.created_on - (compare_time.blank? ? journals[i-1] : compare_time[-1]) > 3*24*3600
                  #         end
                  #       end
                  #     end
                  #   end
                  # end
                end
              end
              bugs.group_by(&:username).each do |u, bgs|
                sumBug += bgs.count
                bugids << bgs.map { |b| b.iid }
                nbugs << {:ids => bgs.map { |b| b.iid }.uniq.join(','), :month => bgs.first.mon, :deptname => bgs.first.deptname, :username => bgs.first.username, :amount => bgs.count}
              end
              nbugs << {:ids => bugids.flatten.uniq.sort.reverse, :month => '', :deptname => '', :username => '合计', :amount => sumBug}
              nbugs
            when "timeout_and_unhandle_bug_coverage" then
              day_feilds = []
              days.each do |day|
                if params[:dwm].to_s == "day"
                  day_feilds << "SUM(CASE WHEN DATE_FORMAT(issues.created_on,'%Y%m%d') = '#{day}' AND TIMESTAMPDIFF(SECOND,
                                 CASE WHEN (iss.times LIKE '%0,%' OR iss.times LIKE '%,0%' OR iss.times LIKE '%,0,%') THEN (CASE WHEN iss.times LIKE '%,0' THEN SUBSTRING_INDEX(SUBSTRING_INDEX(iss.times,',',-2),',',1) ELSE SUBSTRING_INDEX(iss.times,',',-1) END) ELSE issues.created_on END,NOW()) > #{params[:days].to_i*24*3600} THEN 1 ELSE 0 END) AS d_#{day}"
                  day_feilds << "IFNULL(SUM(CASE WHEN DATE_FORMAT(issues.created_on,'%Y%m%d') = '#{day}' AND TIMESTAMPDIFF(SECOND,CASE WHEN (iss.times LIKE '%0,%' OR iss.times LIKE '%,0%' OR iss.times LIKE '%,0,%') THEN (CASE WHEN iss.times LIKE '%,0' THEN SUBSTRING_INDEX(SUBSTRING_INDEX(iss.times,',',-2),',',1) ELSE SUBSTRING_INDEX(iss.times,',',-1) END) ELSE issues.created_on END,NOW()) > #{params[:days].to_i*24*3600} THEN 1 ELSE 0 END)/SUM(CASE WHEN issues.status_id IN (#{IssueStatus::COMMIT_STATUS + ',' + IssueStatus::UNSOLVED_STATUS + ',' + IssueStatus::SOLVED_STATUS}) THEN 1 ELSE 0 END),0) AS l_#{day}"
                end
              end
              Issue.timeout_and_unhandle_bug_coverage(day_feilds.join(","), handle_params_where.join(' and '))
            when "leave_amount_and_solved_rate" then
              row = Issue.leave_amount_and_solved_rate(handle_params_where.join(' and '), nil, nil).first
              hj_u = row.s1bu.to_i + row.s1su.to_i + row.s2bu.to_i + row.s2su.to_i + row.s3bu.to_i + row.s3su.to_i if row
              hj_s = row.s1bs.to_i + row.s1ss.to_i + row.s2bs.to_i + row.s2ss.to_i + row.s3bs.to_i + row.s3ss.to_i if row
              hj_db = (params[:s1b_rate].to_f/100*(row.s1bu + row.s1bs) + params[:s1s_rate].to_f/100*(row.s1su + row.s1ss) + params[:s2b_rate].to_f/100*(row.s2bu + row.s2bs) + params[:s3b_rate].to_f/100*(row.s3bu + row.s3bs) + params[:s3s_rate].to_f/100*(row.s3su + row.s3ss)).round(1) if row
              hj_cz = params[:s1b_rate].to_f/100*(row.s1bu + row.s1bs)-row.s1bs + params[:s1s_rate].to_f/100*(row.s1su + row.s1ss)-row.s1ss + params[:s2b_rate].to_f/100*(row.s2bu + row.s2bs)-row.s2bs + params[:s2s_rate].to_f/100*(row.s2su + row.s2ss)-row.s2ss + params[:s3b_rate].to_f/100*(row.s3bu + row.s3bs)-row.s3bs + params[:s3s_rate].to_f/100*(row.s3su + row.s3ss)-row.s3ss if row
              [['S1必现', row.s1bu, row.s1bs, row.s1bu.to_i + row.s1bs.to_i, (row.s1b_yesterday.to_f*100).round(2).to_s << '%', (row.s1b_today.to_f*100).round(2).to_s << '%', params[:s1b_rate] << '%', (params[:s1b_rate].to_f/100*(row.s1bu + row.s1bs)).round(1), params[:s1b_rate].to_f/100*(row.s1bu.to_i + row.s1bs.to_i) < row.s1bs ? '-' : (params[:s1b_rate].to_f/100*(row.s1bu.to_i + row.s1bs.to_i)-row.s1bs).round(1)],
               ['S1随机', row.s1su, row.s1ss, row.s1su.to_i + row.s1ss.to_i, (row.s1s_yesterday.to_f*100).round(2).to_s << '%', (row.s1s_today.to_f*100).round(2).to_s << '%', params[:s1s_rate] << '%', (params[:s1s_rate].to_f/100*(row.s1su + row.s1ss)).round(1), params[:s1s_rate].to_f/100*(row.s1su.to_i + row.s1ss.to_i) < row.s1ss ? '-' : (params[:s1s_rate].to_f/100*(row.s1su.to_i + row.s1ss.to_i)-row.s1ss).round(1)],
               ['S2必现', row.s2bu, row.s2bs, row.s2bu.to_i + row.s2bs.to_i, (row.s2b_yesterday.to_f*100).round(2).to_s << '%', (row.s2b_today.to_f*100).round(2).to_s << '%', params[:s2b_rate] << '%', (params[:s2b_rate].to_f/100*(row.s2bu + row.s2bs)).round(1), params[:s2b_rate].to_f/100*(row.s2bu.to_i + row.s2bs.to_i) < row.s2bs ? '-' : (params[:s2b_rate].to_f/100*(row.s2bu.to_i + row.s2bs.to_i)-row.s2bs).round(1)],
               ['S2随机', row.s2su, row.s2ss, row.s2su.to_i + row.s2ss.to_i, (row.s2s_yesterday.to_f*100).round(2).to_s << '%', (row.s2s_today.to_f*100).round(2).to_s << '%', params[:s2s_rate] << '%', (params[:s2s_rate].to_f/100*(row.s2su + row.s2ss)).round(1), params[:s2s_rate].to_f/100*(row.s2su.to_i + row.s2ss.to_i) < row.s2ss ? '-' : (params[:s2s_rate].to_f/100*(row.s2su.to_i + row.s2ss.to_i)-row.s2ss).round(1)],
               ['S3必现', row.s3bu, row.s3bs, row.s3bu.to_i + row.s3bs.to_i, (row.s3b_yesterday.to_f*100).round(2).to_s << '%', (row.s3b_today.to_f*100).round(2).to_s << '%', params[:s3b_rate] << '%', (params[:s3b_rate].to_f/100*(row.s3bu + row.s3bs)).round(1), params[:s3b_rate].to_f/100*(row.s3bu.to_i + row.s3bs.to_i) < row.s3bs ? '-' : (params[:s3b_rate].to_f/100*(row.s3bu.to_i + row.s3bs.to_i)-row.s3bs).round(1)],
               ['S3随机', row.s3su, row.s3ss, row.s3su.to_i + row.s3ss.to_i, (row.s3s_yesterday.to_f*100).round(2).to_s << '%', (row.s3s_today.to_f*100).round(2).to_s << '%', params[:s3s_rate] << '%', (params[:s3s_rate].to_f/100*(row.s3su + row.s3ss)).round(1), params[:s3s_rate].to_f/100*(row.s3su.to_i + row.s3ss.to_i) < row.s3ss ? '-' : (params[:s3s_rate].to_f/100*(row.s3su.to_i + row.s3ss.to_i)-row.s3ss).round(1)],
               ['总计', hj_u, hj_s, hj_u + hj_s,
                ((row.s1b_yesterday.to_f + row.s1s_yesterday.to_f + row.s2b_yesterday.to_f + row.s2s_yesterday.to_f + row.s3b_yesterday.to_f + row.s3s_yesterday.to_f)*100/6).round(2).to_s << '%',
                ((row.s1b_today.to_f + row.s1s_today.to_f + row.s2b_today.to_f + row.s2s_today.to_f + row.s3b_today.to_f + row.s3s_today.to_f)*100/6).round(2).to_s << '%', '-',
                hj_db, hj_cz < 0 ? '-' : hj_cz.round(1)]] if row
            when "leave_amount_rank_by_dept" then
              Issue.leave_amount("", handle_params_where.join(' and '), "depts.id", nil).limit(10).map { |d|
                [d.deptname, d.amount, Issue.solved_rate("depts.id = #{d.dId}", "depts.id", nil).first.amount]
              }
            when "leave_amount_rank_by_mokuai" then
              Issue.leave_amount("", handle_params_where.join(' and '), "mokuais.id", nil).limit(10)
            when "leave_amount_rank_by_issue_category" then
              Issue.leave_amount("", handle_params_where.join(' and '), "cf5.value", nil).limit(10)
            when "leave_amount_group_by_reason_and_owner" then
              Issue.leave_amount("", handle_params_where.join(' and '), "issues.mokuai_reason", nil)
            when "bug_verificating_time" then
              Issue.verificate_time_personalize(handle_params_where.join(' and '), nil, nil)
            when "bug_moving_and_back_to_owner" then
              bugs = []
              Issue.bug_moving_and_back_to_owner(handle_params_where.join(' and '), nil, nil).group_by(&:iid).each do |id, details|
                (1..details.size - 1).each do |i|
                  if details[i].cuvalue.present? && details[i].oldvalue.present? && details[i-1].cuvalue.present? && details[i-1].oldvalue.present?
                    if details[i].cuvalue.to_s == details[i-1].oldvalue.to_s && details[i].oldvalue.to_s == details[i-1].cuvalue.to_s
                      bugs << details[i-1]
                      bugs << details[i]
                    end
                  end
                end
              end
              bugs
            when "leave_amount_group_by_owner_and_rom" then
              cons = handle_params_where.join(' and ')
              Issue.leave_amount(",SUM(CASE WHEN probability.name = 'S1-致命' THEN 1 ELSE 0 END) AS s1_a,SUM(CASE WHEN probability.name = 'S2-严重' THEN 1 ELSE 0 END) AS s2_a,SUM(CASE WHEN probability.name = 'S3-一般' THEN 1 ELSE 0 END) AS s3_a", cons, "issues.assigned_to_id", "users.orgNm DESC,amount DESC").map { |iss|
                [iss.deptname, iss.username, iss.s1_a, iss.s2_a, iss.s3_a]
              }
            when "leave_amount_group_by_owner_and_drive" then
              cons = handle_params_where.join(' and ')
              Issue.leave_amount(",SUM(CASE WHEN probability.name = 'S1-致命' THEN 1 ELSE 0 END) AS s1_a,SUM(CASE WHEN probability.name = 'S2-严重' THEN 1 ELSE 0 END) AS s2_a,SUM(CASE WHEN probability.name = 'S3-一般' THEN 1 ELSE 0 END) AS s3_a", cons, "issues.assigned_to_id", "users.orgNm DESC,amount DESC").map { |iss|
                [iss.deptname, iss.username, iss.s1_a, iss.s2_a, iss.s3_a]
              }
          end
      render :text => {:status => 1, :rows => @rows, :days => days}.to_json
    end
  rescue => e
    render_error :message => e.to_s
  end

  def personalize_export_data
    columns = []
    rows = {}

    items = case params[:menuid]
              when "bug_moving_time" then
                columns = [{"问题ID" => "问题ID"}, {"项目" => "项目"}, {"所有状态" => "所有状态"}, {"状态更新时间" => "状态更新时间"},
                           {"状态操作者" => "状态操作者"}, {"作者" => "作者"}, {"指派者" => "指派者"}, {"指派者部门" => "指派者部门"},
                           {"历史指派给" => "历史指派给"}, {"概率" => "概率"}, {"解决版本" => "解决版本"}, {"验证版本" => "验证版本"},
                           {"通过E-consulter分析" => "通过E-consulter分析"}, {"研发分析结论" => "研发分析结论"}, {"类型" => "类型"},
                           {"模块" => "模块"}, {"备注" => "备注"}]
                sql = ["issues.by_tester = 1"]
                sql << "issues.project_id in (#{params[:project_ids]})" if params[:project_ids] && params[:project_ids].to_s != "null"
                sql << "depts.id in (#{params[:assigned_dept_ids]})" if params[:assigned_dept_ids] && params[:assigned_dept_ids].to_s != "null"
                Issue.bug_moving_time(params[:start_dt] || 'start_dt', params[:end_dt] || 'end_dt', params[:status_ids], params[:assigned_to_ids], sql.join(' and '))
              when "bug_analysis_timeout" then
                columns = [{"问题ID" => "问题ID"}, {"指派者" => "指派者"}]
                bugs = []
                Issue.find_by_sql(Issue.analysis_timeout(handle_params_where.join(' and '), nil)).group_by(&:iid).each do |iss, journals|
                  (1..journals.size - 1).each do |i|
                    bugs << {:问题ID => iss, :指派者 => journals[i].username} if journals[i].created_on - journals[i-1].created_on > 3*24*3600
                  end
                end
                bugs
              when "bug_verificating_time" then
                columns = [{"iid" => "问题ID"}, {"amount" => "验证时长(H)"}, {"username" => "作者"}, {"deptname" => "作者部门"}]
                Issue.verificate_time_personalize(handle_params_where.join(' and '), nil, nil)
              when "bug_moving_and_back_to_owner" then
                columns = [{"iid" => "#"}, {"subject" => "标题"}, {"username" => "指派者"}, {"jusername" => "上次指派者"}, {"updated_dt" => "更新时间"}, {"markpoint" => "注释说明"}]
                Issue.bug_moving_and_back_to_owner(handle_params_where.join(' and '), nil, nil)
            end

    columns.each { |c| rows.merge!({c.keys.first => c.values.first}) }
    send_data data_to_xlsx(items, rows).to_stream.read, {:disposition => 'attachment', :encoding => 'utf8',
                                          :stream => false, :type => 'application/xlsx',
                                          :filename => "#{Time.now.strftime('%Y%m%d%H%m%s')}.xlsx"}
  end

  def export
    colomns = {}
    get_colums_by_group.each { |c| colomns.merge!({c => head_name[c.to_s.to_sym]}) }
    send_data data_to_xlsx(get_body_from_data, colomns).to_stream.read, {:disposition => 'attachment', :encoding => 'utf8',
                                                          :stream => false, :type => 'application/xlsx',
                                                          :filename => "#{params[:reportname] + params[:reporttype]}_#{DateTime.now.to_s(:db)}.xlsx"}
  end

  def get_data_by_condition
    cid = params[:condition_id]
    cdn = Condition.find(cid) if cid
    sql = generate_sql(cdn.condition) + " and issues.by_tester = 1"
    if cdn.present? && cdn.name.to_s.include?("bug数量")
      data = Issue.bug_amount("", sql, nil, nil)
    elsif cdn.present? && cdn.name.to_s.include?("有效数量")
      data = Issue.alive_amount("", sql, nil, nil)
    elsif cdn.present? && cdn.name.to_s.include?("发现bug数量")
      data = Issue.found_amount(sql, nil, "issues.project_id,users.orgNm desc,amount desc")
    elsif cdn.present? && cdn.name.to_s.include?("重打开数量")
      data = Issue.reopen_amount(sql, "issues.assigned_to_id", nil)
    elsif cdn.present? && cdn.name.to_s.include?("遗留数量")
      data = Issue.leave_amount(sql, "issues.assigned_to_id", nil)
    elsif cdn.present? && cdn.name.to_s.include?("已解决数量")
      data = Issue.solved_amount(sql, "issues.assigned_to_id", nil)
    elsif cdn.present? && cdn.name.to_s.include?("平均已解的重分配数量")
      data = Issue.avg_reassigned_amount(sql, "issues.assigned_to_id", nil)
    elsif cdn.present? && cdn.name.to_s.include?("已解的重分配数量")
      data = Issue.reassigned_amount(sql, "issues.assigned_to_id", nil)
    elsif cdn.present? && cdn.name.to_s.include?("冗余数量")
      data = Issue.redundancy_amount(sql, "issues.assigned_to_id", nil)
    elsif cdn.present? && cdn.name.to_s.include?("解决率")
      data = Issue.solved_rate(sql, nil, nil)
    elsif cdn.present? && cdn.name.to_s.include?("重分配率")
      data = Issue.reassigned_rate(sql, "issues.assigned_to_id", nil)
    elsif cdn.present? && cdn.name.to_s.include?("重打开率")
      data = Issue.reopen_rate(sql, nil, nil)
    elsif cdn.present? && cdn.name.to_s.include?("分配准确率")
      data = Issue.assigned_correct_rate(sql, nil, nil)
    elsif cdn.present? && cdn.name.to_s.include?("平均未分配时长")
      data = Issue.avg_unassigned_time(sql, nil, "users.orgNm desc,amount desc")
    elsif cdn.present? && cdn.name.to_s.include?("平均未解决时长")
      data = Issue.avg_unsolved_time(sql, nil, "users.orgNm desc,amount desc")
    elsif cdn.present? && cdn.name.to_s.include?("平均未处理时长")
      data = Issue.avg_unhandle_time(sql, nil, "users.orgNm desc,amount desc")
    elsif cdn.present? && cdn.name.to_s.include?("平均未走读时长")
      data = Issue.avg_unwalk_time(sql, nil, "users.orgNm desc,amount desc")
    elsif cdn.present? && cdn.name.to_s.include?("平均未验证时长")
      data = Issue.avg_unverificate_time(sql, nil, "users.orgNm desc,amount desc")
    elsif cdn.present? && cdn.name.to_s.include?("平均分配时长")
      data = Issue.avg_assigned_time(sql, nil, "users.orgNm desc,amount desc")
    elsif cdn.present? && cdn.name.to_s.include?("平均解决时长")
      data = Issue.avg_solved_time(sql, nil, "users.orgNm desc,amount desc")
    elsif cdn.present? && cdn.name.to_s.include?("平均走读时长")
      data = Issue.avg_walk_time(sql, nil, "users.orgNm desc,amount desc")
    elsif cdn.present? && cdn.name.to_s.include?("平均验证时长")
      data = Issue.avg_verificate_time(sql, nil, "users.orgNm desc,amount desc")
    elsif cdn.present? && cdn.name.to_s.include?("平均关闭时长")
      data = Issue.avg_close_time(sql, nil, "users.orgNm desc,amount desc")
    elsif cdn.present? && cdn.name.to_s.include?("bug分析时长")
      data = bug_analyze_time(handle_params_where.join(' and '))
    end
    data
  end

  def display_report_by_type
    limit = params[:more] || 10

    sql = case params[:type]
            when "solved_personal" then
              group_and_limit_report_data(true, "assigoedname", "solved_times DESC", limit)
            when "solved_department" then
              group_and_limit_report_data(true, "orgNm", "solved_times DESC", limit)
            when "unsolved_personal" then
              group_and_limit_report_data(false, "assigoedname", "solved_times DESC", limit)
            when "unsolved_department" then
              group_and_limit_report_data(false, "orgNm", "solved_times DESC", limit)
          end

    render :text => {:rows => JournalDetail.find_by_sql(sql), :message => "success!"}.to_json
  rescue => e
    render :text => {:rows => nil, :message => "Error,#{e.to_s}"}.to_json
  end

  def all_users
    render :text => User.select("id,firstname").to_json
  end

  def issue_report
    @trackers = @project.trackers
    @versions = @project.shared_versions.sort
    @priorities = IssuePriority.all.reverse
    @categories = @project.issue_categories
    @assignees = (Setting.issue_group_assignment? ? @project.principals : @project.users).sort
    @authors = @project.users.sort
    @subprojects = @project.descendants.visible

    @issues_by_tracker = Issue.by_tracker(@project)
    @issues_by_version = Issue.by_version(@project)
    @issues_by_priority = Issue.by_priority(@project)
    @issues_by_category = Issue.by_category(@project)
    @issues_by_assigned_to = Issue.by_assigned_to(@project)
    @issues_by_author = Issue.by_author(@project)
    @issues_by_subproject = Issue.by_subproject(@project) || []

    render :template => "reports/issue_report"
  end

  def issue_report_details
    case params[:detail]
      when "tracker"
        @field = "tracker_id"
        @rows = @project.trackers
        @data = Issue.by_tracker(@project)
        @report_title = l(:field_tracker)
      when "version"
        @field = "fixed_version_id"
        @rows = @project.shared_versions.sort
        @data = Issue.by_version(@project)
        @report_title = l(:field_version)
      when "priority"
        @field = "priority_id"
        @rows = IssuePriority.all.reverse
        @data = Issue.by_priority(@project)
        @report_title = l(:field_priority)
      when "category"
        @field = "category_id"
        @rows = @project.issue_categories
        @data = Issue.by_category(@project)
        @report_title = l(:field_category)
      when "assigned_to"
        @field = "assigned_to_id"
        @rows = (Setting.issue_group_assignment? ? @project.principals : @project.users).sort
        @data = Issue.by_assigned_to(@project)
        @report_title = l(:field_assigned_to)
      when "author"
        @field = "author_id"
        @rows = @project.users.sort
        @data = Issue.by_author(@project)
        @report_title = l(:field_author)
      when "subproject"
        @field = "project_id"
        @rows = @project.descendants.visible
        @data = Issue.by_subproject(@project) || []
        @report_title = l(:field_subproject)
    end

    respond_to do |format|
      if @field
        format.html {}
      else
        format.html { redirect_to :action => 'issue_report', :id => @project }
      end
    end
  end

  def group_and_limit_by_type_sql
    case params[:type]
      when "solved_personal" then
        group_and_limit_report_data(true, "assigoedname", "AVG(solved_time_sconds)", 10)
      when "solved_department" then
        group_and_limit_report_data(true, "orgNm", "AVG(solved_time_sconds)", 10)
      when "unsolved_personal" then
        group_and_limit_report_data(false, "assigoedname", "AVG(solved_time_sconds) DESC", 10)
      when "unsolved_department" then
        group_and_limit_report_data(false, "orgNm", "AVG(solved_time_sconds) DESC", 10)
    end
  end

  def group_and_limit_report_data(is_solved, group_by, order, limit)
    conditions = "projects.id = #{params[:id] || Project.sorted.first.id} AND depts.orgNo not in ('#{Dept.find_by_orgNo(Dept::AVAIS[-1].to_s).all_down_levels.join("','")}')"
    iss1 = Issue.avg_solved_time_ids("(journal_details.prop_key = 'status_id' AND journal_details.value = #{IssueStatus::REPAIRED_STATUS})", conditions, "issues.id", "issues.id,journals.created_on").to_sql
    iss2 = Issue.avg_solved_time_ids("(journal_details.prop_key = 'status_id' AND journal_details.old_value = #{IssueStatus::REPAIRED_STATUS})", conditions, "issues.id", "issues.id,journals.created_on").to_sql

    is_solved ? "select iss1.username as assigoedname,iss1.deptname as orgNm,
      ROUND(AVG(TIMESTAMPDIFF(SECOND,iss1.times,iss2.times))/3600,2) as solved_times from issues
      inner join (#{iss1}) as iss1 on iss1.ids = issues.id inner join (#{iss2}) as iss2 on iss2.ids = issues.id
      inner join users on users.id = issues.assigned_to_id inner join depts on users.orgNo = depts.orgNo
      inner join projects on issues.project_id = projects.id inner join mokuais on mokuais.id = issues.mokuai_name
      group by #{group_by || 'ids'} order by #{order} limit #{limit || 10}" : "select iss.username as assigoedname,iss.deptname as orgNm,amount as solved_times
        from (#{Issue.avg_unhandle_time(conditions, 'issues.assigned_to_id', nil).to_sql}) as iss group by #{group_by || 'ids'} order by #{order} limit #{limit || 10}"
  end

  def bug_analyze_time(where)
    rows = Array.new

    Issue.analyze_time(where).group_by(&:iid).each do |iid, issues|
      projectname = ''
      username = ''
      deptname = ''
      start_at = ''
      end_at = ''
      assigned_name_flag = true
      issues.each do |iss|
        projectname = iss.projectname
        start_at = iss.assigned_time if iss.oldsts == '分配'
        end_at = iss.assigned_time if iss.cursts == '已修复'
        if iss.record == '指派'
          username = iss.toname if assigned_name_flag
          deptname = iss.deptname if assigned_name_flag
          assigned_name_flag = false
        end
      end
      rows << {:ids => iid, :deptname => deptname, :projectname => projectname, :username => username, :opts => '', :cons => '[]', :amount => (start_at.blank? || end_at.blank?) ? 0 : (end_at - start_at).to_s}
      # p "=====id:#{iid} , start:#{start_at} , end:#{end_at} , times:#{(start_at.blank? || end_at.blank?) ? 0 : (end_at - start_at)}======"
    end
    rows
  end

  def count_bug_solved_time(issues = Issue.solved, *params)
    project_id = params[:id].nil? ? Project.sorted.first.id : params[:id].to_i

    issues = []
    group_by_assigned_to_id_issues = []
    assigned_to_ids = issues.select("distinct assigned_to_id").pluck(:assigned_to_id).uniq
    issues.each do |issue|
      issue_statuses = []

      journals = issue.journals.select { |j| j.details.first.prop_key == "status_id" if j.details.present? }
      status_name = journals.present? ? journals.first.old_status.name : issue.status.name
      issue_statuses << {:time => format_time(issue.created_on), :status => status_name, :user => issue.author.name}
      if journals.present?
        journals.each do |j|
          issue_statuses << {:time => format_time(j.created_on), :status => j.new_status.name, :user => j.user.name}
        end
      end

      if issue_statuses.size <= 1
        solved_time = issue.closed_on - issue.created_on
      else
        times = issue_statuses.map { |status| status[:time] }.sort
        solved_time = ((DateTime.parse(times[-1].to_s) - DateTime.parse(times[0].to_s))*24*60*60).to_i
      end

      issues << {:id => issue.id, :assigned_to => issue.assigned_to_id, :solved_time => solved_time}
    end

    assigned_to_ids.each do |id|
      solved_count = 0
      solved_total_times = 0
      issues.each do |i|
        solved_count += 1 if i[:assigned_to] == id
        solved_total_times += i[:solved_time].to_i if i[:assigned_to] == id
      end
      group_by_assigned_to_id_issues << {:name => User.find(id).firstname, :dept => Dept.find_by_orgNo(User.find(id).orgNo), :avg_solved_times => solved_total_times/solved_count}
    end
    group_by_assigned_to_id_issues
  end

  private

  def find_issue_statuses
    @statuses = IssueStatus.sorted.to_a
  end

  def generate_body(issues)
    sum = 0
    total_cons = []
    ids = []
    tbody = "<tbody>"
    issues.each_with_index do |issue, index|
      randon = SecureRandom.uuid
      begin
        redis = Redis.new
        preview_ids = "tmp_#{randon}"
        redis.set(preview_ids, issue[:ids])
        redis.expire(preview_ids, 3600)
      rescue => e
        logger.info("\nRedisError #{e}: (#{File.expand_path(__FILE__)})\n")
      end

      tr = "<tr><th>#{index + 1}</th>"
      get_colums_by_group.each do |th|
        if th.to_s.eql?("opts")
          if issue[:amount].class.to_s != "String" && !issue[:amount].nil? && issue[:amount] >= 0
            tr << "<th>#{generate_details_menu(preview_ids, false, issue[:ids], issue[:username], issue[:deptname], issue[:projectname], issue[:uId], issue[:dId], issue[:pId], issue[:assigned_to_id], issue[:cons])}</th>"
          else
            tr << "<th></th>"
          end
        else
          tr << "<th>#{issue[th.to_sym]}</th>"
          sum += issue[:amount].to_i if th.to_s.eql?("amount") && issue[:amount].class.to_s != "String" && !issue[:amount].nil?
          issue[:ids].to_s.split(',').each do |su|
            ids << su if !ids.include?(su)
          end
        end
      end
      tr << "</tr>"
      tbody += tr
      total_cons = eval(issue[:cons])
    end

    ths = ""
    (1...get_colums_by_group.size-1).each do
      ths << "<th></th>"
    end

    tbody += "<tr>#{ths}<th>合计：</th><th>" + sum.to_s + "</th><th>#{sum > 0 ? generate_details_menu("", true, ids.join(','), "", "", "", "", "", "", "", !params[:reporttype].to_s.include?("bug数量") ? total_cons : []) : ''}</th></tr></tbody>"
    tbody
  end

  def generate_details_menu(preview_ids, isSum, ids, username, deptname, projectname, uid, did, pid, assgid, cons)
    preview_name = (username && username.to_s.empty?) ? (deptname && deptname.to_s.empty? ? projectname : deptname) : username
    preview_href = "/issues?preview=#{preview_ids}"
    showDetails = "<li role=\"presentation\"><a role=\"menuitem\" tabindex=\"-1\" target=\"_blank\" href='#{preview_href}'>预览(#{preview_name.nil? ? '' : preview_name + ')的' + params[:reporttype].to_s}</a></li>"
    showGenerateCondition = "<li role=\"presentation\"><a role=\"menuitem\" tabindex=\"-1\" href='#{void_js}' target='_blank' onclick='onGenerateCondition(this,#{isSum},\"#{ids}\",\"#{username}\",\"#{deptname}\",\"#{projectname}\",\"#{uid}\",\"#{did}\",\"#{pid}\",\"#{assgid}\",#{cons.is_a?(Array) ? cons : eval(cons)});'>生成条件筛选器</a></li>"

    "<div class=\"dropdown\">
      <button class=\"btn btn-default dropdown-toggle\" type=\"button\" data-toggle=\"dropdown\">
         详情
         <span class=\"caret\"></span>
      </button>
      <ul class=\"dropdown-menu\" role=\"menu\" aria-labelledby=\"details\">" + (params[:reporttype].to_s.include?("数量") && !isSum ? showDetails : "") + (params[:reporttype].to_s.include?("数量") && params[:groupby] == "issues.assigned_to_id" ? showGenerateCondition : "") + "
      </ul>
    </div>"
  end

  def get_body_from_data
    select_feilds = handle_params_select.blank? ? "" : ",#{handle_params_select.join(',')}"
    conditions = (handle_params_where << 'issues.by_tester = 1').join(' and ')
    case params[:reporttype]
      when "bug数量"
        conditions = (handle_params_where_conditions << 'issues.by_tester = 1').join(' and ')
        Issue.bug_amount(params[:start_dt], params[:end_dt], select_feilds, conditions, params[:groupby], "amount desc")
      when "有效数量"
        Issue.alive_amount(select_feilds, conditions, params[:groupby], "issues.project_id,users.orgNm desc,amount desc")
      when "发现bug数量"
        groupby = params[:groupby] == "issues.assigned_to_id" ? "CASE WHEN issues.author_id IS NULL THEN cf8.value ELSE issues.author_id END" : params[:groupby]
        Issue.found_amount(select_feilds, conditions, groupby, "issues.project_id,users.orgNm desc,amount desc")
      when "重打开数量"
        Issue.reopen_amount(select_feilds, conditions, params[:groupby] || "issues.assigned_to_id", "issues.project_id,users.orgNm desc,amount desc")
      when "遗留数量"
        Issue.leave_amount(select_feilds, conditions, params[:groupby] || "issues.assigned_to_id", "issues.project_id,users.orgNm desc,amount desc")
      when "已解决数量"
        Issue.solved_amount(select_feilds, conditions, params[:groupby] || "issues.assigned_to_id", "issues.project_id,users.orgNm desc,amount desc")
      when "已解的重分配数量"
        Issue.reassigned_amount(select_feilds, conditions, params[:groupby], "issues.project_id,users.orgNm desc,amount desc")
      when "冗余数量"
        Issue.redundancy_amount(select_feilds, conditions, params[:groupby] || "issues.assigned_to_id", "issues.project_id,users.orgNm desc,amount desc")
      when "平均已解的重分配数量"
        Issue.avg_reassigned_amount(select_feilds, conditions, params[:groupby] || "issues.assigned_to_id", "issues.project_id,users.orgNm desc,amount desc")
      when "解决率"
        Issue.solved_rate(conditions, params[:groupby] || "issues.assigned_to_id", "issues.project_id,users.orgNm desc,amount desc")
      when "重打开率"
        Issue.reopen_rate(conditions, params[:groupby] || "issues.assigned_to_id", "issues.project_id,users.orgNm desc,amount desc")
      when "重分配率"
        Issue.reassigned_rate(conditions, params[:groupby] || "issues.assigned_to_id", "issues.project_id,users.orgNm desc,amount desc")
      when "分配准确率"
        Issue.assigned_correct_rate(conditions, params[:groupby] || "issues.assigned_to_id", "issues.project_id,users.orgNm desc,amount desc")
      when "平均未分配时长"
        Issue.avg_unassigned_time(conditions, params[:groupby], "issues.project_id,users.orgNm desc,amount desc")
      when "平均未解决时长"
        Issue.avg_unsolved_time(conditions, params[:groupby], "issues.project_id,users.orgNm desc,amount desc")
      when "平均未处理时长"
        Issue.avg_unhandle_time(conditions, params[:groupby], "issues.project_id,users.orgNm desc,amount desc")
      when "平均未走读时长"
        Issue.avg_unwalk_time(conditions, params[:groupby], "issues.project_id,users.orgNm desc,amount desc")
      when "平均未验证时长"
        Issue.avg_unverificate_time(conditions, params[:groupby], "issues.project_id,users.orgNm desc,amount desc")
      when "平均关闭时长"
        Issue.avg_close_time(conditions, params[:groupby], "issues.project_id,users.orgNm desc,amount desc")
      when "平均分配时长"
        Issue.avg_assigned_time(conditions, params[:groupby], "issues.project_id,users.orgNm desc,amount desc")
      when "平均解决时长"
        Issue.avg_solved_time(conditions, params[:groupby], "issues.project_id,users.orgNm desc,amount desc")
      when "平均走读时长"
        Issue.avg_walk_time(conditions, params[:groupby], "issues.project_id,users.orgNm desc,amount desc")
      when "平均验证时长"
        Issue.avg_verificate_time(conditions, params[:groupby], "issues.project_id,users.orgNm desc,amount desc")
      when "bug分析时长"
        bug_analyze_time(conditions)
    end
  end

  def get_head_from_columns
    thead = "<thead><tr><th>序号</th>"
    get_colums_by_group.each do |opt|
      thead += "<th>#{head_name[opt.to_sym]}</th>" if head_name.has_key?(opt.to_sym)
    end
    thead += "</tr></thead>"
    thead
  end

  def head_name
    {:mokuai_name => "模块", :mokuai_reason => "归属", :deptname => "部门", :projectname => "项目名称", :username => "姓名", :amount => "数据", :opts => "详情"}
  end

  def get_colums_by_group
    case params[:groupby]
      when "issues.assigned_to_id" then
        ["deptname", "username", "amount", "opts"]
      when "users.orgNm" then
        ["deptname", "amount", "opts"]
      when "issues.project_id" then
        ["projectname", "amount", "opts"]
      when "projects.category" then
        ["projectname", "deptname", "username", "amount", "opts"]
      when "issues.mokuai_name" then
        ["mokuai_name", "amount", "opts"]
      when "issues.mokuai_reason" then
        ["mokuai_reason", "amount", "opts"]
    end
  end

  def countTime_by_type
    case params[:reporttype]
      when "bug数量" then
        "issue.countTime"
      else
        "issues.updated_on"
    end
  end

  def handle_params_select
    sql = []

    if params[:dwm_yn].to_i == 1
      raise "开始时间不能为空" if params[:start_dt].blank?
      raise "结束时间不能为空" if params[:end_dt].blank?

      start_dt = Date.parse params[:start_dt]
      end_dt = Date.parse params[:end_dt]

      raise "开始时间不能大于当前时间" if start_dt > Time.now
      raise "结束时间不能小于开始时间" if end_dt < start_dt

      case params[:dwm]
        when "day"
          days = []
          (start_dt..end_dt).each do |d|
            days << "SUM(CASE WHEN #{countTime_by_type} < '#{d.to_s} 23:59:59' THEN 1 ELSE 0 END) AS d_#{d.to_s.gsub('-', '')}"
          end
          sql << days.join(',')
        when "month"
          months = []
          months_sql = []
          (start_dt..end_dt).each do |m|
            months << m.to_s.split('-')[0].to_s + '-' + m.to_s.split('-')[1].to_s
          end

          months.uniq.each do |mon|
            months_sql << "SUM(CASE WHEN DATE_FORMAT(#{countTime_by_type},'%Y-%m') = '#{mon.to_s}' THEN 1 ELSE 0 END) AS m_#{mon.to_s.gsub('-', '')}"
          end
          sql << months_sql.join(',')
        when "week"
          weeks = []
          (start_dt..end_dt).each do |w|
            weeks << w.cweek
          end
          weeks.uniq.each do |week|
            sql << "SUM(CASE WHEN WEEKOFYEAR(#{countTime_by_type}) = #{week} THEN 1 ELSE 0 END) AS w_#{week}"
          end
      end
    end
    sql
  end

  def handle_params_where_conditions
    conditions = []

    if params[:role_value] && params[:role_value] != "null" && params[:role_value].strip != ""
      if params[:role].to_s == "depts.id"
        ids = []
        Dept.where("id in (#{params[:role_value]})").each do |dept|
          ids << "'" + Dept.find_by_orgNo(dept.orgNo).all_down_levels.join("','") + "'"
        end
        users = User.where("orgNo in #{ids.join(',')}")
        conditions << "users.id in (#{users.map{|user| user.id}.join(',')})"
      else
        conditions << "users.id in (#{params[:role_value]})"
      end
    end
    if params[:project] && params[:project].to_s != "project_id"
      conditions << "projects.#{params[:project]} in ('#{params[:project_value].to_s.split(',').join('\',\'')}')" if params[:project_value] && params[:project_value] != "null" && params[:project_value].strip != ""
    else
      conditions << "issues.#{params[:project]} in (#{params[:project_value]})" if params[:project_value] && params[:project_value] != "null" && params[:project_value].strip != ""
    end
    if params[:dwm_yn] && params[:dwm_yn].to_i == 1
      conditions << "issues.created_on > '#{params[:start_dt] || '2016-09-01'} 00:00:00' and issues.created_on < '#{params[:end_dt] || Time.now.strftime('%Y-%m-%d')} 23:59:59'"
    end
    conditions << "issues.by_tester = #{params[:by_tester].to_i}" if params[:by_tester].present?
    conditions << "cf2.value in ('#{params[:probability].to_s.split(',').join('\',\'')}')" if params[:probability] && params[:probability] != "null" && params[:probability].strip != ""
    conditions << "issues.priority_id in (#{params[:priority_id]})" if params[:priority_id] && params[:priority_id] != "null" && params[:priority_id].strip != ""
    conditions
  end

  def handle_params_where
    conditions = []

    if params[:role_value] && params[:role_value] != "null" && params[:role_value].strip != ""
      if params[:role].to_s == "depts.id"
        ids = []
        Dept.where("id in (#{params[:role_value]})").each do |dept|
          ids << find_all_children_ids_by_orgno(dept.orgNo)
        end
        conditions << "#{params[:role]} in (#{ids.join(',')})"
      else
        if WITH_USER_REPORTS.include?(params[:reporttype].to_s)
          conditions << "users.id in (#{params[:role_value]})"
        else
          conditions << "#{params[:role]} in (#{params[:role_value]})"
        end
      end
    end
    if params[:project] && params[:project].to_s != "project_id"
      conditions << "projects.#{params[:project]} in ('#{params[:project_value].to_s.split(',').join('\',\'')}')" if params[:project_value] && params[:project_value] != "null" && params[:project_value].strip != ""
    else
      conditions << "issues.#{params[:project]} in (#{params[:project_value]})" if params[:project_value] && params[:project_value] != "null" && params[:project_value].strip != ""
    end
    if params[:dwm_yn] && params[:dwm_yn].to_i == 1
      if params[:created_time_yn] && params[:created_time_yn].to_i == 1
        conditions << "issues.created_on > '#{params[:start_dt] || '2016-09-01'} 00:00:00' and issues.created_on < '#{params[:end_dt] || Time.now.strftime('%Y-%m-%d')} 23:59:59'"
      elsif params[:created_time_yn] && params[:created_time_yn].to_i == 2
        conditions << "issues.updated_on > '#{params[:start_dt] || '2016-09-01'} 00:00:00' and issues.updated_on < '#{params[:end_dt] || Time.now.strftime('%Y-%m-%d')} 23:59:59'"
      else
        # conditions << "journals.created_on > '#{params[:start_dt] || '2016-09-01'} 00:00:00' and journals.created_on < '#{params[:end_dt] || Time.now.strftime('%Y-%m-%d')} 23:59:59'"
        conditions << "journals.created_on < '#{params[:end_dt] || Time.now.strftime('%Y-%m-%d')} 00:00:00'"
      end
    end
    conditions << "issues.by_tester = #{params[:by_tester].to_i}" if params[:by_tester].present?
    conditions << "cf2.value in ('#{params[:probability].to_s.split(',').join('\',\'')}')" if params[:probability] && params[:probability] != "null" && params[:probability].strip != ""
    conditions << "issues.priority_id in (#{params[:priority_id]})" if params[:priority_id] && params[:priority_id] != "null" && params[:priority_id].strip != ""
    conditions
  end

  def handle_params_order_by
    "#{params[:project].to_s}"
    # if params[:project].to_s != "project_id"
    #   sql << "#{params[:project]} in ('#{params[:project_value].to_s.split(',').join('\',\'')}')"
    # else
    #   sql << "#{params[:project]} in (#{params[:project_value]})"
    # end
  end

  def find_all_children_ids_by_orgno(org_no)
    depts = ''
    depts << "'" + Dept.find_by_orgNo(org_no).all_down_levels.join("','") + "',"
    Dept.where("orgNo in (#{depts[0..-2]})").pluck(:id).join(',')
  end

  def generate_sql(condition)
    reg = /depts.id in \((.*?)\)/i
    reg.match(condition)
    depts = ''
    if $1
      ids = $1
      Dept.where("id in (#{ids})").each do |dept|
        depts << find_all_children_ids_by_orgno(dept.orgNo)
      end
    end
    condition = condition.gsub('("me")', "(#{User.current.id.to_s})").gsub('issues.orgNo', "users.orgNo").gsub('issues.cf2', 'cf2.value').gsub('issues.category', 'projects.category').gsub(reg, "depts.id in (#{ids})")
    condition.eql?("(())") ? "" : "#{condition}"
  end

  # return two time's day or month
  def count_start_to_end_days
    res = []
    start_dt = params[:start_dt] || "2016-09-01"
    end_dt = params[:end_dt] || Time.now.strftime("%Y-%m-%d")

    (Date.parse(start_dt)..Date.parse(end_dt)).each do |d|
      if params[:dwm].to_s == "day"
        res << d.to_s.gsub('-', '')
      elsif params[:dwm].to_s == "week"
        res << d.cweek
      elsif params[:dwm].to_s == "month"
        res << d.to_s.split('-')[0].to_s + d.to_s.split('-')[1].to_s unless res.include?(d.to_s.split('-')[0].to_s + d.to_s.split('-')[1].to_s)
      end
    end

    res.uniq!

    res
  end

  def report_name
    case params[:type]
      when "solved_personal" then
        "个人平均解决时长排名"
      when "solved_department" then
        "部门平均解决时长排名"
      when "unsolved_personal" then
        "个人未处理时长排名"
      when "unsolved_department" then
        "部门未处理时长排名"
    end
  end

  def generate_table(opts)
    table = "<table "
    table << "class=\"#{opts[:class] || "table table-striped table-bordered table-hover"}\" "
    table << "id=\"#{opts[:id] || "reportDataList"}\">"
    table << opts[:thead] || "<thead><tr><th>排名</th><th>姓名</th><th>部门</th><th>数据</th><th>详情</th></tr></thead>"
    table << opts[:tbody] if opts[:tbody]
    table << "</table>"
  end

  def generate_pagination(opts)
    total = opts[:total] || 0
    per_page = opts[:per_page] || Report::PER_PAGE
    pages = (total.to_i / per_page.to_i) + 1
    pagination = "<nav><ul class=\"pagination\">"
    pagination << "<li class=\"#{1 == opts[:cur_page].to_i ? 'disabled' : 'active'}\">
                   <a href=\"javascript:onPaginate(" + total.to_s + "," + per_page.to_s + "," + (opts[:cur_page].to_i == 1 ? 1 : opts[:cur_page].to_i - 1).to_s + ")\">&laquo;</a></li>"

    (1..pages).each { |page|
      pagination << "<li class=\"#{page == opts[:cur_page].to_i ? 'disabled' : 'active'}\">
                     <a href=\"javascript:onPaginate(" + total.to_s + "," + per_page.to_s + "," + page.to_s + ")\">#{page}</a></li>"
    }

    pagination << "<li class=\"#{pages == opts[:cur_page].to_i ? 'disabled' : 'active'}\">
                   <a href=\"javascript:onPaginate(" + total.to_s + "," + per_page.to_s + "," + (pages == opts[:cur_page].to_i ? pages : opts[:cur_page].to_i + 1).to_s + ")\">&raquo;</a></li></ul></nav>"
  end

end
