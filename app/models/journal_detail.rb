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

class JournalDetail < ActiveRecord::Base
  belongs_to :journal
  attr_protected :id

  scope :format_time_to_normal,lambda{|time|
    # "(CASE WHEN #{time}/60 < 1 THEN CONCAT(ROUND(#{time}),'秒')
    #        WHEN #{time}/60 < 60 THEN CONCAT(FLOOR(#{time}/60),'分',FLOOR(#{time}%60),'秒')
    #        WHEN #{time}/3600 < 24 THEN CONCAT(FLOOR(#{time}/3600), '时',FLOOR((#{time}%3600)/60), '分',ROUND(#{time}%60), '秒')
    #        WHEN #{time}/3600 > 24 THEN CONCAT(FLOOR(#{time}/3600/24),'天',FLOOR((#{time}%3600)/3600), '时',FLOOR((#{time}%3600)/60), '分',ROUND(#{time}%60), '秒') END)"
    "CONCAT(FLOOR(#{time}/3600/24),'天',FLOOR((#{time}%3600)/3600), '时',FLOOR((#{time}%3600)/60), '分',ROUND(#{time}%60), '秒')"
  }

  scope :issues,lambda{|status_ids| select("i.id,assigoed.firstname AS assigoedname,assigoed.orgNm,MAX(j.created_on),MIN(j.created_on),
                                         CONVERT(TIMEDIFF(MAX(j.created_on),MIN(j.created_on)),CHAR) AS solved_times,
                                         TIMESTAMPDIFF(SECOND,MIN(j.created_on),MAX(j.created_on)) AS solved_time_sconds")
                                 .joins("AS d LEFT JOIN journals AS j ON j.id = d.journal_id LEFT JOIN issues AS i ON i.id = j.journalized_id
                                         LEFT JOIN users AS author ON author.id = i.author_id LEFT JOIN users AS assigoed ON assigoed.id = i.assigned_to_id
                                         LEFT JOIN users AS journalied ON journalied.id = j.user_id LEFT JOIN issue_statuses AS statuse ON statuse.id = i.status_id
                                         LEFT JOIN issue_statuses AS history_status ON history_status.id = d.old_value AND d.prop_key = 'status_id'")
                                 .where("statuse.id in (#{status_ids})")}

  scope :assigned_correct_rate,lambda{|sql,group_by,order|
    select("GROUP_CONCAT(DISTINCT issues.id) as iid,issues.assigned_to_id,projects.name AS projectname,users.orgNm AS deptname,users.firstname AS username,'' AS opts,'[]' AS cons,
            GROUP_CONCAT(DISTINCT CASE WHEN issues.assigned_to_id = journals.user_id AND journal_details.value = 11 THEN issues.id ELSE 0 END) AS amount").
    joins("INNER JOIN journals ON journals.id = journal_details.journal_id
           INNER JOIN issues ON issues.id = journals.journalized_id
           INNER JOIN users ON users.id = issues.assigned_to_id
           INNER JOIN depts ON depts.orgNo = users.orgNo
           INNER JOIN projects ON projects.id = issues.project_id
           INNER JOIN mokuais ON mokuais.id = issues.mokuai_name").
    where("issues.status_id IN (#{IssueStatus::SOLVED_STATUS}) AND #{sql.blank? ? '1=1' : sql}").
    group("#{group_by || 'issues.id'}").
    order("#{order || 'issues.id'}")
  }

  scope :reassigned_amount,lambda{|feilds,sql,group_by,order|
    cons = [["AND","status_id"," LIKE ",IssueStatus::SOLVED_STATUS.split(',')],["AND","ls_status_id"," = ",[IssueStatus::REASSIGNED_STATUS]]]
    select("GROUP_CONCAT(DISTINCT issues.id) as ids,DATE_FORMAT(issues.created_on,'%Y%m%d') AS ymd,DATE_FORMAT(issues.created_on,'%Y%m') AS ym,projects.id AS pId,depts.id AS dId,users.id AS uId,
            issues.assigned_to_id,projects.name as projectname,projects.category as categoryname,users.orgNm AS deptname,users.firstname AS username,'' AS opts,'#{cons}' AS cons,mokuais.name AS mokuai_name,mokuais.reason AS mokuai_reason,
            SUM(CASE WHEN issues.status_id in (#{IssueStatus::SOLVED_STATUS}) AND journal_details.prop_key = 'status_id' AND journal_details.old_value = #{IssueStatus::REASSIGNED_STATUS} THEN 1 ELSE 0 END) AS amount#{feilds}").
    joins("INNER JOIN journals ON journals.id = journal_details.journal_id
           INNER JOIN issues ON issues.id = journals.journalized_id
           INNER JOIN projects ON issues.project_id = projects.id
           INNER JOIN users ON users.id = issues.assigned_to_id
           INNER JOIN depts ON depts.orgNo = users.orgNo
           INNER JOIN mokuais ON mokuais.id = issues.mokuai_name").
    where("issues.status_id in (#{IssueStatus::SOLVED_STATUS}) AND (journal_details.prop_key = 'status_id' AND journal_details.old_value = #{IssueStatus::REASSIGNED_STATUS}) AND #{sql.blank? ? '1=1' : sql}").
    group("#{group_by || 'issues.id'}").
    order("#{order || 'amount desc'}")
  }

  scope :avg_unsolved_time,lambda{|sql,group_by,order|
    select("DISTINCT issues.id as ids,DATE_FORMAT(issues.created_on,'%Y%m%d') AS ymd,DATE_FORMAT(issues.created_on,'%Y%m') AS ym,mokuais.name AS mokuai_name,mokuais.reason AS mokuai_reason,
            issues.assigned_to_id,projects.name as projectname,projects.category as categoryname,users.orgNm AS deptname,users.firstname AS username,'' AS opts,'[]' AS cons,projects.id AS pId,depts.id AS dId,users.id AS uId,
            TIMESTAMPDIFF(SECOND,(CASE WHEN journal_details.prop_key = 'status_id' AND journal_details.old_value = #{IssueStatus::ASSIGNED_STATUS} THEN journals.created_on ELSE NOW() END),NOW()) AS amount").
    joins("INNER JOIN journals ON journals.id = journal_details.journal_id
           INNER JOIN issues ON issues.id = journals.journalized_id
           INNER JOIN projects ON issues.project_id = projects.id
           INNER JOIN users ON users.id = issues.assigned_to_id
           INNER JOIN depts ON depts.orgNo = users.orgNo
           INNER JOIN mokuais ON mokuais.id = issues.mokuai_name").
    where("issues.status_id in (#{IssueStatus::ANALYSIS_STATUS + ',' + IssueStatus::LEAVE_STATUS}) AND #{sql.blank? ? '1=1' : sql}").
    # group("#{group_by || 'issues.id'}").
    order("#{order || 'amount desc'}")
  }

  scope :avg_unwalk_time,lambda{|sql,group_by,order|
    select("GROUP_CONCAT(DISTINCT issues.id) as ids,DATE_FORMAT(issues.created_on,'%Y%m%d') AS ymd,DATE_FORMAT(issues.created_on,'%Y%m') AS ym,projects.id AS pId,users.id AS uId,depts.id AS dId,
            issues.assigned_to_id,projects.name as projectname,projects.category as categoryname,users.orgNm AS deptname,users.firstname AS username,'' AS opts,'[]' AS cons,
            TIMESTAMPDIFF(SECOND,IFNULL(SUBSTRING_INDEX(GROUP_CONCAT(DISTINCT CASE WHEN journal_details.value = #{IssueStatus::REPAIRED_STATUS} THEN journals.created_on END),',',-1),NOW()),NOW()) AS amount").
    joins("LEFT JOIN journals ON journals.id = journal_details.journal_id
           LEFT JOIN issues ON issues.id = journals.journalized_id
           LEFT JOIN projects ON issues.project_id = projects.id
           LEFT JOIN users ON users.id = issues.assigned_to_id
           LEFT JOIN depts ON depts.orgNo = users.orgNo").
    where("((journal_details.prop_key = 'status_id' AND journal_details.value = #{IssueStatus::REPAIRED_STATUS}) OR (journal_details.prop_key = 'status_id' AND journal_details.old_value = #{IssueStatus::REPAIRED_STATUS})) AND #{sql.blank? ? '1=1' : sql}").
    group("#{group_by || 'issues.id'}").having("amount >= 0").
    order("#{order || 'amount desc'}")
  }

  scope :avg_unverificate_time,lambda{|sql,group_by,order|
    select("GROUP_CONCAT(DISTINCT issues.id) as ids,DATE_FORMAT(issues.created_on,'%Y%m%d') AS ymd,DATE_FORMAT(issues.created_on,'%Y%m') AS ym,
            issues.assigned_to_id,projects.name as projectname,projects.category as categoryname,users.orgNm AS deptname,users.firstname AS username,'' AS opts,'[]' AS cons,
            TIMESTAMPDIFF(SECOND,(CASE WHEN journal_details.prop_key = 'status_id' AND journal_details.value in (#{IssueStatus::REPAIRED_STATUS + ',' + IssueStatus::VERIFICATED_STATUS}) THEN journals.created_on ELSE NOW() END),NOW()) AS amount").
    joins("LEFT JOIN journals ON journals.id = journal_details.journal_id
           LEFT JOIN issues ON issues.id = journals.journalized_id
           LEFT JOIN projects ON issues.project_id = projects.id
           LEFT JOIN users ON users.id = issues.assigned_to_id
           LEFT JOIN depts ON depts.orgNo = users.orgNo").
    where("issues.status_id in (#{IssueStatus::REPAIRED_STATUS + ',' + IssueStatus::VERIFICATED_STATUS}) AND journal_details.prop_key = 'status_id' AND journal_details.value in (#{IssueStatus::REPAIRED_STATUS + ',' + IssueStatus::VERIFICATED_STATUS}) AND #{sql.blank? ? '1=1' : sql}").
    group("#{group_by || 'issues.id,journal_details.value'}").having("amount >= 0").
    order("#{order || 'amount desc'}")
  }

  scope :avg_close_time,lambda{|sql,group_by,order|
    select("GROUP_CONCAT(DISTINCT issues.id) as ids,DATE_FORMAT(issues.created_on,'%Y%m%d') AS ymd,DATE_FORMAT(issues.created_on,'%Y%m') AS ym,
            issues.assigned_to_id,projects.name as projectname,projects.category as categoryname,users.orgNm AS deptname,users.firstname AS username,'' AS opts,'[]' AS cons,
            (SUM(TIMESTAMPDIFF(SECOND,(CASE WHEN journal_details.prop_key = 'status_id' AND journal_details.old_value = #{IssueStatus::COMMIT_STATUS} THEN journals.created_on ELSE NOW() END),NOW())) - SUM(TIMESTAMPDIFF(SECOND,(CASE WHEN journal_details.prop_key = 'status_id' AND journal_details.value = #{IssueStatus::CLOSE_STATUS} THEN journals.created_on ELSE NOW() END),NOW()))) AS amount").
    joins("LEFT JOIN journals ON journals.id = journal_details.journal_id
           LEFT JOIN issues ON issues.id = journals.journalized_id
           LEFT JOIN projects ON issues.project_id = projects.id
           LEFT JOIN users ON users.id = issues.assigned_to_id
           LEFT JOIN depts ON depts.orgNo = users.orgNo").
    where("issues.status_id = #{IssueStatus::CLOSE_STATUS} AND #{sql.blank? ? '1=1' : sql}").
    group("#{group_by || 'issues.assigned_to_id'}").having("amount >= 0").
    order("#{order || 'amount desc'}")
  }

  scope :avg_walk_time,lambda{|sql,group_by,order|
    select("GROUP_CONCAT(DISTINCT issues.id) as ids").
    joins("LEFT JOIN journals ON journals.id = journal_details.journal_id
           LEFT JOIN issues ON issues.id = journals.journalized_id
           LEFT JOIN projects ON issues.project_id = projects.id
           LEFT JOIN users ON users.id = issues.assigned_to_id
           LEFT JOIN depts ON depts.orgNo = users.orgNo").
    where("journal_details.prop_key = 'status_id' AND journal_details.old_value = #{IssueStatus::VERIFICATED_STATUS} AND #{sql.blank? ? '1=1' : sql}").
    group("#{group_by || 'issues.assigned_to_id'}")
  }

  scope :bug_moving_time, lambda { |sql, group_by, order, status_ids|
    table_with_status = self.bug_moving_time_creating_with_status(sql, group_by, order, status_ids).to_sql
    table_without_status = self.bug_moving_time_creating_without_status(sql, group_by, order, status_ids).to_sql
    self.find_by_sql("select * from (#{table_with_status}) as issue union (#{table_without_status})")
  }

  scope :bug_moving_time_creating_with_status, lambda { |sql, group_by, order, status_ids|
    sql << " AND issues.status_id in (#{status_ids})" unless status_ids.blank?
    select("cu_status.name AS '所有状态',issues.id AS '问题ID',projects.name AS '项目',DATE_FORMAT(journals.created_on,'%Y-%m-%d %H:%m:%s') AS '更新时间',jourer.firstname AS '状态操作者',assigned.firstname AS '指派者','' AS '历史指派给',
            cf2.value AS '概率',cf3.value AS '解决版本',cf13.value AS '验证版本',cf11.value AS '通过E-consulter分析',cf12.value AS '研发分析结论',cf5.value AS '类型',mokuais.name AS '模块',author.firstname AS '作者',
            assigned.orgNm AS '指派者部门',issues.description AS '备注'")
    .joins("LEFT JOIN journals ON journals.id = journal_details.journal_id
            LEFT JOIN issues ON issues.id = journals.journalized_id
            LEFT JOIN projects ON projects.id = issues.project_id
            LEFT JOIN users AS jourer ON jourer.id = journals.user_id
            LEFT JOIN users AS assigned ON assigned.id = issues.assigned_to_id
            LEFT JOIN depts ON depts.orgNo = assigned.orgNo
            LEFT JOIN users AS author ON author.id = issues.author_id
            LEFT JOIN mokuais ON issues.mokuai_name = mokuais.id
            LEFT JOIN issue_statuses AS cu_status ON issues.status_id = cu_status.id
            LEFT JOIN custom_values AS cf2 ON cf2.customized_id = issues.id AND cf2.custom_field_id = 2 AND cf2.customized_type = 'Issue'
            LEFT JOIN custom_values AS cf3 ON cf3.customized_id = issues.id AND cf3.custom_field_id = 3 AND cf3.customized_type = 'Issue'
            LEFT JOIN custom_values AS cf5 ON cf5.customized_id = issues.id AND cf5.custom_field_id = 5 AND cf5.customized_type = 'Issue'
            LEFT JOIN custom_values AS cf11 ON cf11.customized_id = issues.id AND cf11.custom_field_id = 11 AND cf11.customized_type = 'Issue'
            LEFT JOIN custom_values AS cf12 ON cf12.customized_id = issues.id AND cf12.custom_field_id = 12 AND cf12.customized_type = 'Issue'
            LEFT JOIN custom_values AS cf13 ON cf13.customized_id = issues.id AND cf13.custom_field_id = 13 AND cf13.customized_type = 'Issue'")
    .where("#{sql.blank? ? '1=1' : sql}")
    .group("issues.id").having("IFNULL(FIND_IN_SET('status_id',GROUP_CONCAT(journal_details.prop_key)),0) = 0")
    .order("#{order || 'issues.id,journals.created_on'}")
  }

  scope :bug_moving_time_creating_without_status, lambda { |sql, group_by, order, status_ids|
    feilds = "ifnull(cu_status.name,ls_status.name) as '所有状态',"
    unless status_ids.blank?
      sql << " AND ((journal_details.prop_key = 'status_id' AND journal_details.old_value in (#{status_ids})) OR (journal_details.prop_key = 'status_id' AND journal_details.value IN (#{status_ids})))"
      feilds = "CASE WHEN journal_details.prop_key = 'status_id' AND journal_details.old_value IN (#{status_ids}) THEN ls_status.name WHEN journal_details.prop_key = 'status_id' AND journal_details.value IN (#{status_ids}) THEN cu_status.name END AS '所有状态',"
    end
    select("#{feilds}issues.id AS '问题ID',projects.name AS '项目',DATE_FORMAT(journals.created_on,'%Y-%m-%d %H:%m:%s') AS '更新时间',jourer.firstname AS '状态操作者',assigned.firstname AS '指派者','' AS '历史指派给',
            cf2.value AS '概率',cf3.value AS '解决版本',cf13.value AS '验证版本',cf11.value AS '通过E-consulter分析',cf12.value AS '研发分析结论',cf5.value AS '类型',mokuais.name AS '模块',author.firstname AS '作者',
            assigned.orgNm AS '指派者部门',issues.description AS '备注'")
    .joins("LEFT JOIN journals ON journals.id = journal_details.journal_id
            LEFT JOIN issues ON issues.id = journals.journalized_id
            LEFT JOIN projects ON projects.id = issues.project_id
            INNER JOIN issue_statuses AS ls_status ON journal_details.old_value = ls_status.id AND journal_details.prop_key = 'status_id'
            INNER JOIN issue_statuses AS cu_status ON journal_details.value = cu_status.id AND journal_details.prop_key = 'status_id'
            LEFT JOIN users AS jourer ON jourer.id = journals.user_id
            LEFT JOIN users AS assigned ON assigned.id = issues.assigned_to_id
            LEFT JOIN depts ON depts.orgNo = assigned.orgNo
            LEFT JOIN users AS author ON author.id = issues.author_id
            LEFT JOIN mokuais ON issues.mokuai_name = mokuais.id
            LEFT JOIN custom_values AS cf2 ON cf2.customized_id = issues.id AND cf2.custom_field_id = 2 AND cf2.customized_type = 'Issue'
            LEFT JOIN custom_values AS cf3 ON cf3.customized_id = issues.id AND cf3.custom_field_id = 3 AND cf3.customized_type = 'Issue'
            LEFT JOIN custom_values AS cf5 ON cf5.customized_id = issues.id AND cf5.custom_field_id = 5 AND cf5.customized_type = 'Issue'
            LEFT JOIN custom_values AS cf11 ON cf11.customized_id = issues.id AND cf11.custom_field_id = 11 AND cf11.customized_type = 'Issue'
            LEFT JOIN custom_values AS cf12 ON cf12.customized_id = issues.id AND cf12.custom_field_id = 12 AND cf12.customized_type = 'Issue'
            LEFT JOIN custom_values AS cf13 ON cf13.customized_id = issues.id AND cf13.custom_field_id = 13 AND cf13.customized_type = 'Issue'")
    .where("#{sql.blank? ? '1=1' : sql}")
    .order("#{order || 'issues.id,journals.created_on'}")
  }

  scope :issue_journal_details, lambda {|sql, group_by, order_by|
    select("journal_details.*,journals.created_on as jcreated,issues.*")
    .joins("left join journals on journals.id = journal_details.journal_id left join issues on issues.id = journals.journalized_id")
    .where("#{sql}").order("#{order_by}")
  }

  def custom_field
    if property == 'cf'
      @custom_field ||= CustomField.find_by_id(prop_key)
    end
  end

  def value=(arg)
    write_attribute :value, normalize(arg)
  end

  def old_value=(arg)
    write_attribute :old_value, normalize(arg)
  end

  private

  def normalize(v)
    case v
    when true
      "1"
    when false
      "0"
    when Date
      v.strftime("%Y-%m-%d")
    else
      v
    end
  end
end
