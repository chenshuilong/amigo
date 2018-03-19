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

class Issue < ActiveRecord::Base
  include Redmine::SafeAttributes
  include Redmine::Utils::DateCalculation
  include Redmine::I18n
  before_save :set_parent_id
  include Redmine::NestedSet::IssueNestedSet
  include ApiHelper

  serialize :umpirage_approver_id, Array

  belongs_to :project
  belongs_to :tracker
  belongs_to :status, :class_name => 'IssueStatus'
  belongs_to :author, :class_name => 'User'
  belongs_to :tfde, :class_name => 'User'
  belongs_to :assigned_to, :class_name => 'Principal'
  belongs_to :fixed_version, :class_name => 'Version'
  belongs_to :app_version, :class_name => 'Version', :foreign_key => 'app_version_id'
  belongs_to :integration_version, :class_name => 'Version', :foreign_key => 'integration_version_id'
  belongs_to :priority, :class_name => 'IssuePriority'
  belongs_to :category, :class_name => 'IssueCategory'
  belongs_to :mokuai, :class_name => 'Mokuai', :foreign_key => 'mokuai_name'

  has_many :journals, :as => :journalized, :dependent => :destroy, :inverse_of => :journalized
  has_many :visible_journals,
           lambda { where(["(#{Journal.table_name}.private_notes = ? OR (#{Project.allowed_to_condition(User.current, :view_private_notes)}))", false]) },
           :class_name => 'Journal',
           :as => :journalized

  has_many :time_entries, :dependent => :destroy
  has_and_belongs_to_many :changesets, lambda { order("#{Changeset.table_name}.committed_on ASC, #{Changeset.table_name}.id ASC") }

  has_many :relations_from, :class_name => 'IssueRelation', :foreign_key => 'issue_from_id', :dependent => :delete_all
  has_many :relations_to, :class_name => 'IssueRelation', :foreign_key => 'issue_to_id', :dependent => :delete_all
  has_many :gerrits, :class_name => 'IssueGerrit', :foreign_key => 'issue_id', :dependent => :destroy # IssueGerrit

  acts_as_attachable :after_add => :attachment_added, :after_remove => :attachment_removed
  acts_as_customizable
  acts_as_watchable
  acts_as_searchable :columns => ['subject', "#{table_name}.description"],
                     :preload => [:project, :status, :tracker],
                     :scope => lambda { |options| options[:open_issues] ? self.open : self.all }

  acts_as_event :title => Proc.new { |o| "#{o.tracker.name} ##{o.id} (#{o.status}): #{o.subject}" },
                :url => Proc.new { |o| {:controller => 'issues', :action => 'show', :id => o.id} },
                :type => Proc.new { |o| 'issue' + (o.closed? ? ' closed' : '') }

  acts_as_activity_provider :scope => preload(:project, :author, :tracker),
                            :author_key => :author_id

  DONE_RATIO_OPTIONS = %w(issue_field issue_status)

  attr_reader :current_journal
  delegate :notes, :notes=, :private_notes, :private_notes=, :to => :current_journal, :allow_nil => true

  validates_presence_of :subject, :project, :tracker

  validates :priority_id, presence: true, inclusion: { in: IssuePriority.ids }, :if => Proc.new { |issue|
    tracker.core_fields.include?("priority_id") && (issue.new_record? || issue.priority_id_changed?)
  }
  validates_presence_of :status, :if => Proc.new { |issue| issue.new_record? || issue.status_id_changed? }
  validates_presence_of :author, :if => Proc.new { |issue| issue.new_record? || issue.author_id_changed? }
  validates_inclusion_of :done_ratio, :in => 0..100

  validates :subject, length: {maximum: 140}
  validates :estimated_hours, :numericality => {:greater_than_or_equal_to => 0, :allow_nil => true, :message => :invalid}
  validates :start_date, :date => true
  validates :due_date, :date => true
  validates :mokuai_reason, presence: true, unless: -> { !tracker.core_fields.include?("mokuai_reason") }
  validates :mokuai_name, :numericality => {:only_integer => true, :message => :invalid}, unless: -> { !tracker.core_fields.include?("mokuai_name") }
  validate :validate_issue, :validate_required_fields, :validate_repeat_issue


  attr_protected :id

  scope :visible, lambda { |*args|
    unless ProjectPolicy.new(User.current, :project).view_all?
      ids = User.current.projects.map(&:id).join(",")
      sql = ids.present? ? "issues.project_id in (#{ids})" : "projects.id is null"
    else
      sql = ""
    end 
    joins(:project).
        where(Issue.visible_condition(args.shift || User.current, *args)).where(sql)
  }

  scope :open, lambda { |*args|
    is_closed = args.size > 0 ? !args.first : false
    joins(:status).
        where("#{IssueStatus.table_name}.is_closed = ?", is_closed)
  }

  scope :recently_updated, lambda { order("#{Issue.table_name}.updated_on DESC") }
  scope :on_active_project, lambda {
    joins(:project).
        where("#{Project.table_name}.status = ?", Project::STATUS_ACTIVE)
  }
  scope :fixed_version, lambda { |versions|
    ids = [versions].flatten.compact.map { |v| v.is_a?(Version) ? v.id : v }
    ids.any? ? where(:fixed_version_id => ids) : where('1=0')
  }
  scope :assigned_to, lambda { |arg|
    arg = Array(arg).uniq
    ids = arg.map { |p| p.is_a?(Principal) ? p.id : p }
    ids += arg.select { |p| p.is_a?(User) }.map(&:group_ids).flatten.uniq
    ids.compact!
    ids.any? ? where(:assigned_to_id => ids) : none
  }

  scope :solved, lambda { where("status_id in (#{IssueStatus::SOLVED_STATUS})") }
  scope :daily_by_test, lambda { |time| where("issues.by_tester = 1 AND DATE_FORMAT(issues.created_on,'%Y-%m-%d') <= '#{time}'") }

  scope :unsolved, lambda { |arg|
    where("status_id in (#{IssueStatus::UNSOLVED_STATUS})")
  }

  scope :format_time_to_normal, lambda { |time|
    # "(CASE WHEN #{time}/60 < 1 THEN CONCAT(ROUND(#{time}),'秒')
    #        WHEN #{time}/60 < 60 THEN CONCAT(FLOOR(#{time}/60),'分',FLOOR(#{time}%60),'秒')
    #        WHEN #{time}/3600 < 24 THEN CONCAT(FLOOR(#{time}/3600), '时',FLOOR((#{time}%3600)/60), '分',ROUND(#{time}%60), '秒')
    #        WHEN #{time}/3600 > 24 THEN CONCAT(FLOOR(#{time}/3600/24),'天',FLOOR((#{time}%3600)/3600), '时',FLOOR((#{time}%3600)/60), '分',ROUND(#{time}%60), '秒') END)"

    #"CONCAT(FLOOR(#{time}/3600/24),'天',FLOOR((#{time}%3600)/3600), '时',FLOOR((#{time}%3600)/60), '分',ROUND(#{time}%60), '秒')"
    "ROUND(#{time}/3600,2)"
  }

  scope :joins_without_details, lambda { |arg|
    joins("LEFT JOIN custom_values AS cf2 ON cf2.customized_id = issues.id AND cf2.custom_field_id = 2 AND cf2.customized_type = 'Issue'
           LEFT JOIN enumerations AS probability ON probability.id = issues.priority_id AND probability.type = 'IssuePriority'
           INNER JOIN custom_values AS cf5 ON cf5.customized_id = issues.id AND cf5.custom_field_id = 5 AND cf5.customized_type = 'Issue'
           INNER JOIN users ON users.id = issues.assigned_to_id
           INNER JOIN depts ON users.orgNo = depts.orgNo
           INNER JOIN projects ON issues.project_id = projects.id
           INNER JOIN mokuais ON mokuais.id = issues.mokuai_name #{arg}")
  }

  scope :joins_with_details, lambda { |arg|
    joins_without_details("LEFT JOIN journals ON journals.journalized_id = issues.id
           LEFT JOIN journal_details ON journal_details.journal_id = journals.id #{arg}")
  }

  scope :bug_amount, lambda { |start_dt, end_dt, feilds, sql, group_by, order|
    ids_with_time = Report::Original.bug_amount_with_time(sql)
    group_by = (group_by || 'issue.assigned_to_id').gsub('issues.assigned_to_id', 'issue.assigned_to_id')
    reg = /assigned_to_id in \((.*?)\)/i
    reg.match(sql)
    sql3 = "1=1"
    sql3 = "issue.assigned_to_id in (#{$1})" if $1
    sql1 = sql.gsub("assigned_to_id in (#{$1}) and","")

    find_by_sql Report::Original.bug_amount(show_feilds_by_group(group_by),feilds,sql,sql1,sql3,ids_with_time,group_by,order || 'amount desc')
  }

  scope :found_amount, lambda { |feilds, sql, group_by, order|
    select("#{show_feilds_by_group(group_by)},COUNT(issues.id) AS amount,'[]' AS cons,'' AS opts#{feilds}").
    joins("LEFT JOIN custom_values AS cf2 ON cf2.customized_id = issues.id AND cf2.custom_field_id = 2 AND cf2.customized_type = 'Issue'
           LEFT JOIN custom_values AS cf8 ON cf8.customized_id = issues.id AND cf8.custom_field_id = 8 AND cf8.customized_type = 'Issue'
           LEFT JOIN enumerations AS probability ON probability.id = issues.priority_id AND probability.type = 'IssuePriority'
           LEFT JOIN users ON IFNULL(issues.author_id,cf8.value) = users.id
           LEFT JOIN depts ON users.orgNo = depts.orgNo
           LEFT JOIN mokuais ON mokuais.id = issues.mokuai_name
           LEFT JOIN projects ON issues.project_id = projects.id
           LEFT JOIN journals ON journals.journalized_id = issues.id
           LEFT JOIN journal_details ON journal_details.journal_id = journals.id").
    where("#{sql || '1=1'}").
    group("#{group_by || 'issues.author_id'}").
    order("#{order || 'amount desc'}")
  }

  scope :reopen_amount, lambda { |feilds,sql,group_by,order|
    cons = [["AND", "ls_status_id", " = ", [IssueStatus::REOPEN_STATUS]]]
    select("#{show_feilds_by_group(group_by)},COUNT(journal_details.id) AS amount,'#{cons}' AS cons,'' AS opts#{feilds}").
    joins("LEFT JOIN custom_values AS cf2 ON cf2.customized_id = issues.id AND cf2.custom_field_id = 2 AND cf2.customized_type = 'Issue'
           LEFT JOIN custom_values AS cf8 ON cf8.customized_id = issues.id AND cf8.custom_field_id = 8 AND cf8.customized_type = 'Issue'
           LEFT JOIN enumerations AS probability ON probability.id = issues.priority_id AND probability.type = 'IssuePriority'
           LEFT JOIN users ON users.id = issues.assigned_to_id
           LEFT JOIN depts ON users.orgNo = depts.orgNo
           LEFT JOIN mokuais ON mokuais.id = issues.mokuai_name
           LEFT JOIN projects ON issues.project_id = projects.id
           LEFT JOIN journals ON journals.journalized_id = issues.id
           LEFT JOIN journal_details ON journal_details.journal_id = journals.id").
    where("(journal_details.prop_key = 'status_id' AND journal_details.old_value = #{IssueStatus::REPAIRED_STATUS} AND journal_details.value = #{IssueStatus::REOPEN_STATUS}) AND #{sql || '1=1'}").
    group("#{group_by || 'issues.assigned_to_id'}").
    order("#{order || 'amount desc'}")
  }

  scope :leave_amount, lambda { |feilds, sql, group_by, order|
    cons = [["AND", "status_id", " = ", (IssueStatus::ANALYSIS_STATUS + ',' + IssueStatus::LEAVE_STATUS).split(',')]]
    select("#{show_feilds_by_group(group_by)},'' AS opts,'#{cons}' AS cons,CAST(mokuais.name AS CHAR) AS model,cf5.value AS issue_category,
            SUM(CASE WHEN issues.status_id in (#{IssueStatus::ANALYSIS_STATUS + ',' + IssueStatus::LEAVE_STATUS}) THEN 1 ELSE 0 END) AS amount#{feilds}").
    joins_without_details("").
    where("issues.status_id in (#{IssueStatus::ANALYSIS_STATUS + ',' + IssueStatus::LEAVE_STATUS}) AND issues.by_tester = 1 AND #{sql.blank? ? '1=1' : sql}").
    group("#{group_by || 'issues.id'}").
    order("#{order || 'amount desc'}")
  }

  scope :solved_amount, lambda { |feilds, sql, group_by, order|
    cons = [["AND", "status_id", " = ", IssueStatus::SOLVED_STATUS.split(',')]]
    select("#{show_feilds_by_group(group_by)},'' AS opts,'#{cons}' AS cons,
            SUM(CASE WHEN issues.status_id in (#{IssueStatus::SOLVED_STATUS}) THEN 1 ELSE 0 END) AS amount#{feilds}").
    joins_without_details("").
    where("issues.status_id in (#{IssueStatus::SOLVED_STATUS}) AND #{sql.blank? ? '1=1' : sql}").
    group("#{group_by || 'issues.id'}").
    order("#{order || 'amount desc'}")
  }

  scope :reassigned_amount, lambda { |feilds, sql, group_by, order|
    group_by = group_by || "ids"
    fds = show_feilds_by_group_mokuai(group_by)
    group_by = group_by.to_s.include?("mokuai") ? group_by.gsub('issues.','') : "ids"
    table = JournalDetail.reassigned_amount(feilds, sql, "issues.id", order).to_sql
    self.find_by_sql("select #{fds},opts,cons from (#{table}) as iss group by #{group_by}")
  }

  scope :avg_reassigned_amount, lambda { |feilds, sql, group_by, order|
    table = JournalDetail.reassigned_amount(feilds, sql, "issues.id", order).to_sql
    self.find_by_sql("select iss.*,avg(amount) AS amount from (#{table}) as iss group by assigned_to_id")
  }

  scope :redundancy_amount, lambda { |feilds, sql, group_by, order|
    cons = [["AND", "status_id", " <> ", IssueStatus::SOLVED_STATUS.split(',') + IssueStatus::LEAVE_STATUS.split(',') + [IssueStatus::COMMIT_STATUS] + [IssueStatus::ANALYSIS_STATUS]]]
    select("#{show_feilds_by_group(group_by)},'' AS opts,'#{cons}' AS cons,
            SUM(CASE WHEN issues.status_id not in (#{IssueStatus::SOLVED_STATUS + ',' + IssueStatus::LEAVE_STATUS + ',' + IssueStatus::COMMIT_STATUS + ',' + IssueStatus::ANALYSIS_STATUS}) THEN 1 ELSE 0 END) AS amount#{feilds}").
    joins_without_details("").
    where("issues.status_id not in (#{IssueStatus::SOLVED_STATUS + ',' + IssueStatus::LEAVE_STATUS + ',' + IssueStatus::COMMIT_STATUS + ',' + IssueStatus::ANALYSIS_STATUS}) AND #{sql || '1=1'}").
    group("#{group_by || 'issues.id'}").
    order("#{order || 'amount desc'}")
  }

  scope :alive_amount, lambda { |feilds, sql, group_by, order|
    cons = [["AND", "status_id", " = ", IssueStatus::ANALYSIS_STATUS.split(',') + IssueStatus::COMMIT_STATUS.split(',') + IssueStatus::LEAVE_STATUS.split(',') + IssueStatus::SOLVED_STATUS.split(',')]]
    select("#{show_feilds_by_group(group_by)},COUNT(issues.id) AS amount,'#{cons}' AS cons,'' AS opts#{feilds}").joins_without_details("").
    where("issues.status_id in (#{IssueStatus::ANALYSIS_STATUS + ',' + IssueStatus::COMMIT_STATUS + ',' + IssueStatus::LEAVE_STATUS + ',' + IssueStatus::SOLVED_STATUS}) AND #{sql || '1=1'}").
    group("#{group_by || 'issues.assigned_to_id'}").
    order("#{order || 'amount desc'}")
  }

  scope :solved_rate, lambda { |sql, group_by, order|
    select("GROUP_CONCAT(DISTINCT issues.id) as ids,DATE_FORMAT(issues.created_on,'%Y%m%d') AS ymd,DATE_FORMAT(issues.created_on,'%Y%m') AS ym,mokuais.name as mokuai_name,mokuais.reason AS mokuai_reason,
            issues.assigned_to_id,projects.name as projectname,projects.category as categoryname,users.orgNm AS deptname,users.firstname AS username,'' AS opts,'[]' AS cons,
            CONCAT(round(SUM(CASE WHEN issues.status_id IN (#{IssueStatus::SOLVED_STATUS}) THEN 1 ELSE 0 END) / (SUM(CASE WHEN issues.status_id IN (#{IssueStatus::ANALYSIS_STATUS + ',' + IssueStatus::SOLVED_STATUS + ',' + IssueStatus::LEAVE_STATUS}) THEN 1 ELSE 0 END))*100,2),'%') AS amount").
    joins_without_details("").
    where("#{sql.blank? ? '1=1' : sql}").
    group("#{group_by || 'issues.assigned_to_id'}").
    order("#{order || 'amount asc'}")
  }

  scope :reassigned_rate, lambda { |sql, group_by, order|
    table = self.reassigned_rate_ids(sql,nil,'issues.id').to_sql
    self.find_by_sql("select ids,ymd,ym,issues.assigned_to_id,projectname,categoryname,deptname,username,opts,cons,mokuais.name as mokuai_name,
          mokuais.reason as mokuai_reason,CASE WHEN iss.solved = 0 THEN 0 ELSE CONCAT(round(SUM(iss.reassigned)/SUM(iss.solved)*100,2),'%') END AS amount from (#{table}) as iss
        INNER JOIN issues ON issues.id = iss.ids
        LEFT JOIN custom_values AS cf2
          ON cf2.customized_id = issues.id
            AND cf2.custom_field_id = 2
            AND cf2.customized_type = 'Issue'
        LEFT JOIN enumerations AS probability
          ON probability.id = issues.priority_id
            AND probability.type = 'IssuePriority'
        INNER JOIN custom_values AS cf5
          ON cf5.customized_id = issues.id
            AND cf5.custom_field_id = 5
            AND cf5.customized_type = 'Issue'
        INNER JOIN users
          ON users.id = issues.assigned_to_id
        INNER JOIN depts
          ON users.orgNo = depts.orgNo
        INNER JOIN projects
          ON issues.project_id = projects.id
        INNER JOIN mokuais
          ON mokuais.id = issues.mokuai_name
        LEFT JOIN journals
          ON journals.journalized_id = issues.id
        LEFT JOIN journal_details
          ON journal_details.journal_id = journals.id
        GROUP BY #{group_by} ORDER BY #{order}")
  }

  scope :reassigned_rate_ids, lambda { |sql, group_by, order|
    select("GROUP_CONCAT(DISTINCT issues.id) as ids,DATE_FORMAT(issues.created_on,'%Y%m%d') AS ymd,DATE_FORMAT(issues.created_on,'%Y%m') AS ym,
            issues.assigned_to_id,projects.name as projectname,projects.category as categoryname,users.orgNm AS deptname,users.firstname AS username,'' AS opts,'[]' AS cons,
            COUNT(DISTINCT journal_details.id) AS reassigned,SUM(DISTINCT CASE WHEN issues.status_id IN (#{IssueStatus::SOLVED_STATUS}) THEN 1 ELSE 0 END) AS solved").
    joins_with_details("").
    where("(journal_details.prop_key = 'status_id' AND journal_details.old_value = #{IssueStatus::REASSIGNED_STATUS}) AND #{sql.blank? ? '1=1' : sql}").
    group("#{group_by || 'issues.id'}").
    order("#{order || 'amount desc'}")
  }

  # scope :reassigned_rate, lambda { |sql, group_by, order|
  #   select("GROUP_CONCAT(issues.id) as ids,DATE_FORMAT(issues.created_on,'%Y%m%d') AS ymd,DATE_FORMAT(issues.created_on,'%Y%m') AS ym,
  #           issues.assigned_to_id,projects.name as projectname,projects.category as categoryname,users.orgNm AS deptname,users.firstname AS username,'' AS opts,'[]' AS cons,
  #           SUM(CASE WHEN (journal_details.prop_key = 'status_id' AND journal_details.value = #{IssueStatus::REASSIGNED_STATUS}) OR (journal_details.prop_key = 'status_id' AND journal_details.old_value = #{IssueStatus::REASSIGNED_STATUS}) THEN 1 ELSE 0 END)/SUM(CASE WHEN issues.status_id in (#{IssueStatus::SOLVED_STATUS}) THEN 1 ELSE 0 END) AS amount").
  #   joins_with_details("").
  #   where("#{sql.blank? ? '1=1' : sql}").
  #   group("#{group_by || 'issues.id'}").
  #   order("#{order || 'amount desc'}")
  # }

  scope :assigned_correct_rate, lambda { |sql, group_by, order|
    table = JournalDetail.assigned_correct_rate(sql, nil, nil).to_sql
    find_by_sql("select iid,issues.assigned_to_id,projectname,deptname,username,mokuais.name as mokuai_name,mokuais.reason as mokuai_reason,opts,cons,CONCAT(SUM(CASE WHEN iss.amount LIKE '%,%' THEN 1 ELSE 0 END)/COUNT(iss.iid)*100,'%') AS amount
      from (#{table}) as iss
      inner join issues on issues.id = iss.iid
      inner join users on users.id = issues.assigned_to_id
      inner join depts on depts.orgNo = users.orgNo
      inner join projects on projects.id = issues.project_id
      inner join mokuais on mokuais.id = issues.mokuai_name group by #{group_by} order by amount")
  }

  # scope :reopen_rate, lambda { |sql, group_by, order|
  #   reopen_table = "select GROUP_CONCAT(DISTINCT iss1.iid) as ids,issues.assigned_to_id,projects.id as pId,
  #       projects.name as projectname,projects.category as categoryname,depts.id as dId,mokuais.reason as mokuai_reason,
  #       users.orgNm AS deptname,users.id as uId,users.firstname AS username,mokuais.name as mokuai_name,
  #       SUM(ifnull(iss1.amount,0) + ifnull(iss2.amount,0)) as amount,'' as opts,'' as cons from (
  #     SELECT
  #       issues.id as iid,COUNT(DISTINCT journal_details.id) AS amount
  #     FROM `issues`
  #       LEFT JOIN custom_values AS cf2
  #         ON cf2.customized_id = issues.id
  #           AND cf2.custom_field_id = 2
  #           AND cf2.customized_type = 'Issue'
  #       LEFT JOIN enumerations AS probability
  #         ON probability.id = issues.priority_id
  #           AND probability.type = 'IssuePriority'
  #       INNER JOIN custom_values AS cf5
  #         ON cf5.customized_id = issues.id
  #           AND cf5.custom_field_id = 5
  #           AND cf5.customized_type = 'Issue'
  #       INNER JOIN users
  #         ON users.id = issues.assigned_to_id
  #       INNER JOIN depts
  #         ON users.orgNo = depts.orgNo
  #       INNER JOIN projects
  #         ON issues.project_id = projects.id
  #       INNER JOIN mokuais
  #         ON mokuais.id = issues.mokuai_name
  #       LEFT JOIN journals
  #         ON journals.journalized_id = issues.id
  #       LEFT JOIN journal_details
  #         ON journal_details.journal_id = journals.id
  #     WHERE ((journal_details.prop_key = 'status_id' AND journal_details.old_value = 10)
  #            AND issues.status_id <> 10 AND #{sql || '1=1'})
  #     GROUP BY issues.id
  #     ORDER BY issues.id,journals.created_on
  #     ) as iss1
  #     left join
  #     (SELECT
  #       issues.id AS iid,(sum(case when journal_details.prop_key = 'status_id' and journal_details.old_value = 10 then 1 else 0 end)+1) as amount
  #     FROM `issues`
  #       LEFT JOIN custom_values AS cf2
  #         ON cf2.customized_id = issues.id
  #           AND cf2.custom_field_id = 2
  #           AND cf2.customized_type = 'Issue'
  #       LEFT JOIN enumerations AS probability
  #         ON probability.id = issues.priority_id
  #           AND probability.type = 'IssuePriority'
  #       INNER JOIN custom_values AS cf5
  #         ON cf5.customized_id = issues.id
  #           AND cf5.custom_field_id = 5
  #           AND cf5.customized_type = 'Issue'
  #       INNER JOIN users
  #         ON users.id = issues.assigned_to_id
  #       INNER JOIN depts
  #         ON users.orgNo = depts.orgNo
  #       INNER JOIN projects
  #         ON issues.project_id = projects.id
  #       INNER JOIN mokuais
  #         ON mokuais.id = issues.mokuai_name
  #       LEFT JOIN journals
  #         ON journals.journalized_id = issues.id
  #       LEFT JOIN journal_details
  #         ON journal_details.journal_id = journals.id
  #     WHERE (issues.status_id = 10 AND journal_details.prop_key = 'status_id' AND #{sql || '1=1'})
  #     GROUP BY issues.id
  #     ORDER BY issues.id,journals.created_on
  #     ) as iss2 on iss1.iid = iss2.iid
  #     INNER JOIN issues ON issues.id = iss1.iid
  #     LEFT JOIN custom_values AS cf2
  #       ON cf2.customized_id = issues.id
  #         AND cf2.custom_field_id = 2
  #         AND cf2.customized_type = 'Issue'
  #     LEFT JOIN enumerations AS probability
  #       ON probability.id = issues.priority_id
  #         AND probability.type = 'IssuePriority'
  #     INNER JOIN custom_values AS cf5
  #       ON cf5.customized_id = issues.id
  #         AND cf5.custom_field_id = 5
  #         AND cf5.customized_type = 'Issue'
  #     INNER JOIN users
  #       ON users.id = issues.assigned_to_id
  #     INNER JOIN depts
  #       ON users.orgNo = depts.orgNo
  #     INNER JOIN projects
  #       ON issues.project_id = projects.id
  #     INNER JOIN mokuais
  #       ON mokuais.id = issues.mokuai_name
  #     GROUP BY #{group_by || 'issues.assigned_to_id'}
  #     ORDER BY #{order || 'amount desc'}"
  #   solved_table = self.solved_amount("",sql,group_by,order).to_sql
  #   joins_by_group =
  #       case group_by
  #         when "issues.assigned_to_id" then
  #           "reopen.assigned_to_id = solved.assigned_to_id"
  #         when "users.orgNm" then
  #           "reopen.dId = solved.dId"
  #         when "issues.project_id" then
  #           "reopen.pId = solved.pId"
  #         when "issues.mokuai_name" then
  #           "reopen.mokuai_name = solved.mokuai_name"
  #         when "issues.mokuai_reason" then
  #           "reopen.mokuai_reason = solved.mokuai_reason"
  #       end
  #   self.find_by_sql("select reopen.assigned_to_id,reopen.pId,reopen.projectname,reopen.categoryname,reopen.dId,reopen.mokuai_reason,
  #       reopen.deptname,reopen.uId,reopen.username,reopen.mokuai_name,
  #       CONCAT(round(reopen.amount*100/solved.amount,2),'%') as amount,reopen.opts,reopen.cons from (#{reopen_table}) as reopen inner join (#{solved_table}) as solved on #{joins_by_group}")
  # }

  scope :reopen_rate, lambda { |sql, group_by, order|
    select("#{show_feilds_by_group(group_by)},'' AS cons,'' AS opts,
      CONCAT(round(COUNT(DISTINCT CASE WHEN journal_details.prop_key = 'status_id' AND journal_details.old_value = #{IssueStatus::REPAIRED_STATUS} AND journal_details.value = #{IssueStatus::REOPEN_STATUS} THEN journal_details.id END)*100/COUNT(DISTINCT CASE WHEN issues.status_id IN (#{IssueStatus::SOLVED_STATUS}) THEN issues.id END),2),'%') AS amount").
    joins("LEFT JOIN custom_values AS cf2 ON cf2.customized_id = issues.id AND cf2.custom_field_id = 2 AND cf2.customized_type = 'Issue'
           LEFT JOIN custom_values AS cf8 ON cf8.customized_id = issues.id AND cf8.custom_field_id = 8 AND cf8.customized_type = 'Issue'
           LEFT JOIN enumerations AS probability ON probability.id = issues.priority_id AND probability.type = 'IssuePriority'
           LEFT JOIN users ON users.id = issues.assigned_to_id
           LEFT JOIN depts ON users.orgNo = depts.orgNo
           LEFT JOIN mokuais ON mokuais.id = issues.mokuai_name
           LEFT JOIN projects ON issues.project_id = projects.id
           LEFT JOIN journals ON journals.journalized_id = issues.id
           LEFT JOIN journal_details ON journal_details.journal_id = journals.id").
    where("#{sql || '1=1'}").
    group("#{group_by || 'issues.assigned_to_id'}").
    order("#{order || 'amount desc'}")
  }

  scope :redundancy_rate, lambda { |sql, group_by, order|
    select("GROUP_CONCAT(issues.id) as ids,DATE_FORMAT(issues.created_on,'%Y%m%d') AS ymd,DATE_FORMAT(issues.created_on,'%Y%m') AS ym,
            issues.assigned_to_id,projects.name as projectname,projects.category as categoryname,users.orgNm AS deptname,users.firstname AS username,'' AS opts,'[]' AS cons,
            CONCAT(SUM(CASE WHEN issues.status_id not in (#{IssueStatus::SOLVED_STATUS + ',' + IssueStatus::LEAVE_STATUS + ',' + IssueStatus::COMMIT_STATUS}) THEN 1 ELSE 0 END)/COUNT(*)*100,'%') AS amount").
    joins_without_details("").
    where("#{sql.blank? ? '1=1' : sql}").
    group("#{group_by || 'issues.assigned_to_id'}").
    order("#{order || 'amount desc'}")
  }

  scope :unassigned_time, lambda { |sql, group_by, order|
    select("GROUP_CONCAT(issues.id) as ids,DATE_FORMAT(issues.created_on,'%Y%m%d') AS ymd,DATE_FORMAT(issues.created_on,'%Y%m') AS ym,
            issues.assigned_to_id,projects.name as projectname,projects.category as categoryname,users.orgNm AS deptname,users.firstname AS username,'' AS opts,'[]' AS cons,
            #{format_time_to_normal("CONVERT(TIMEDIFF(NOW(),(CASE WHEN journal_details.prop_key = 'status_id' AND journal_details.old_value = #{IssueStatus::COMMIT_STATUS} THEN journals.created_on ELSE NOW() END)),CHAR)")} AS amount").
    joins_with_details("").
    where("#{sql.blank? ? '1=1' : sql}").
    group("#{group_by || 'issues.id'}").having("amount > 0").
    order("#{order || 'amount desc'}")
  }

  scope :avg_unassigned_time, lambda { |sql, group_by, order|
    select("#{show_feilds_by_group(group_by)},'' AS opts,'[]' AS cons,
            #{format_time_to_normal("AVG(TIMESTAMPDIFF(SECOND,issues.created_on,NOW()))")} AS amount").
    joins_with_details("").
    where("issues.status_id = #{IssueStatus::COMMIT_STATUS} AND #{sql.blank? ? '1=1' : sql}").
    group("#{group_by || 'issues.assigned_to_id'}").having("amount >= 0").
    order("#{order || 'amount desc'}")
  }

  scope :avg_unsolved_time, lambda { |sql, group_by, order|
    table = JournalDetail.avg_unsolved_time(sql, nil, order).to_sql
    self.find_by_sql("select ids,assigned_to_id,pId,projectname,categoryname,dId,deptname,uId,username,mokuai_reason,mokuai_name,
      opts,cons,#{format_time_to_normal("AVG(amount)")} AS amount from (#{table}) as iss group by #{group_by_group(group_by)}")
  }

  scope :avg_unhandle_time, lambda { |sql, group_by, order|
    select("#{show_feilds_by_group(group_by)},'' AS opts,'[]' AS cons,
            #{format_time_to_normal("AVG(TIMESTAMPDIFF(SECOND,(CASE WHEN journal_details.prop_key = 'status_id' AND journal_details.old_value in (#{IssueStatus::ANALYSIS_STATUS + ',' + IssueStatus::LEAVE_STATUS}) THEN journals.created_on ELSE NOW() END),NOW()))")} AS amount").
    joins_with_details("").
    where("#{sql.blank? ? '1=1' : sql}").
    group("#{group_by || 'issues.assigned_to_id'}").having("amount >= 0").
    order("#{order || 'amount desc'}")
  }

  scope :timeout_and_unhandle_bug_coverage, lambda{|feilds,sql|
    table = self.timeout_and_unhandle_bugs(sql).to_sql
    find_by_sql("select #{feilds},projectname from (#{table}) as iss inner join issues on iss.id = issues.id group by issues.project_id")
  }

  scope :timeout_and_unhandle_bugs, lambda{|sql|
    select("issues.id,projects.name as projectname,
            GROUP_CONCAT(DISTINCT CASE WHEN journal_details.prop_key = 'assigned_to_id' AND journal_details.value = issues.assigned_to_id THEN IFNULL(journals.created_on,issues.created_on) ELSE (CASE WHEN issues.assigned_to_id = journals.user_id THEN IFNULL(journals.created_on,issues.created_on) ELSE 0 END) END) AS times").
    joins("LEFT JOIN custom_values AS cf2 ON cf2.customized_id = issues.id AND cf2.custom_field_id = 2 AND cf2.customized_type = 'Issue'
           LEFT JOIN enumerations AS probability ON probability.id = issues.priority_id AND probability.type = 'IssuePriority'
           LEFT JOIN custom_values AS cf5 ON cf5.customized_id = issues.id AND cf5.custom_field_id = 5 AND cf5.customized_type = 'Issue'
           LEFT JOIN users ON users.id = issues.assigned_to_id
           LEFT JOIN depts ON users.orgNo = depts.orgNo
           LEFT JOIN projects ON issues.project_id = projects.id
           LEFT JOIN mokuais ON mokuais.id = issues.mokuai_name
           LEFT JOIN journals ON journals.journalized_id = issues.id
           LEFT JOIN journal_details ON journal_details.journal_id = journals.id").
    where("projects.category = 1 AND projects.status = 1 AND issues.status_id IN (#{IssueStatus::LEAVE_STATUS}) AND #{sql.blank? ? '1=1' : sql}").
    group("issues.id").
    order("issues.id,journals.created_on")
  }

  scope :avg_unwalk_time, lambda { |sql, group_by, order|
    table = self.avg_unwalk_time_ids(sql).to_sql
    self.find_by_sql("select ids,assigned_to_id,projectname,mokuai_name,mokuai_reason,categoryname,deptname,username,pId,uId,dId,opts,cons,#{format_time_to_normal("AVG(times)")} AS amount
      from (#{table}) as iss group by #{group_by_group(group_by)}")
  }

  scope :avg_unwalk_time_ids, lambda { |sql|
    select("GROUP_CONCAT(DISTINCT issues.id) AS ids,issues.assigned_to_id,projects.name as projectname,projects.category as categoryname,users.orgNm AS deptname,users.firstname AS username,'' AS opts,'[]' AS cons,mokuais.name AS mokuai_name,mokuais.reason AS mokuai_reason,
            projects.id AS pId,users.id AS uId,depts.id AS dId,TIMESTAMPDIFF(SECOND,IFNULL(SUBSTRING_INDEX(GROUP_CONCAT(DISTINCT CASE WHEN journal_details.value = #{IssueStatus::REPAIRED_STATUS} THEN journals.created_on END),',',-1),NOW()),NOW()) AS times").
    joins_with_details("").
    where("((journal_details.prop_key = 'status_id' AND journal_details.value = #{IssueStatus::REPAIRED_STATUS}) OR (journal_details.prop_key = 'status_id' AND journal_details.old_value = #{IssueStatus::REPAIRED_STATUS})) AND #{sql || '1=1'}").
    group("issues.id").
    order("issues.id,journals.created_on")
  }

  scope :avg_unverificate_time, lambda { |sql, group_by, order|
    table = self.avg_unverificate_time_ids(sql).to_sql
    self.find_by_sql("select ids,assigned_to_id,projectname,mokuai_name,mokuai_reason,categoryname,deptname,username,pId,uId,dId,opts,cons,#{format_time_to_normal("AVG(times)")} AS amount
      from (#{table}) as iss group by #{group_by_group(group_by)}")
  }

  scope :avg_unverificate_time_ids, lambda { |sql|
    select("GROUP_CONCAT(DISTINCT issues.id) AS ids,issues.assigned_to_id,projects.name as projectname,projects.category as categoryname,users.orgNm AS deptname,users.firstname AS username,'' AS opts,'[]' AS cons,mokuais.name AS mokuai_name,mokuais.reason AS mokuai_reason,
            projects.id AS pId,users.id AS uId,depts.id AS dId,TIMESTAMPDIFF(SECOND,IFNULL(SUBSTRING_INDEX(GROUP_CONCAT(DISTINCT CASE WHEN journal_details.value IN (#{IssueStatus::REPAIRED_STATUS + ',' + IssueStatus::VERIFICATED_STATUS}) THEN journals.created_on END),',',-1),NOW()),NOW()) AS times").
    joins_with_details("").
    where("issues.status_id IN (#{IssueStatus::REPAIRED_STATUS + ',' + IssueStatus::VERIFICATED_STATUS}) AND #{sql || '1=1'}").
    group("issues.id").
    order("issues.id,journals.created_on")
  }

  scope :avg_close_time, lambda { |sql, group_by, order|
    table = self.avg_close_time_ids(sql).to_sql
    self.find_by_sql("select ids,assigned_to_id,projectname,mokuai_name,mokuai_reason,categoryname,deptname,username,pId,uId,dId,opts,cons,#{format_time_to_normal("AVG(times)")} AS amount
      from (#{table}) as iss group by #{group_by_group(group_by)}")
  }

  scope :avg_close_time_ids, lambda { |sql|
    select("GROUP_CONCAT(DISTINCT issues.id) AS ids,issues.assigned_to_id,projects.name as projectname,projects.category as categoryname,users.orgNm AS deptname,users.firstname AS username,'' AS opts,'[]' AS cons,mokuais.name AS mokuai_name,mokuais.reason AS mokuai_reason,
            projects.id AS pId,users.id AS uId,depts.id AS dId,TIMESTAMPDIFF(SECOND,issues.created_on,IFNULL(SUBSTRING_INDEX(GROUP_CONCAT(DISTINCT CASE WHEN journal_details.prop_key = 'status_id' AND journal_details.value = #{IssueStatus::CLOSE_STATUS} THEN journals.created_on END),',',-1),issues.created_on)) AS times").
    joins_with_details("").
    where("issues.status_id = #{IssueStatus::CLOSE_STATUS} AND #{sql || '1=1'}").
    group("issues.id").
    order("issues.id,journals.created_on")
  }

  scope :avg_assigned_time, lambda { |sql, group_by, order|
    select("GROUP_CONCAT(issues.id) as ids,DATE_FORMAT(issues.created_on,'%Y%m%d') AS ymd,DATE_FORMAT(issues.created_on,'%Y%m') AS ym,mokuais.name AS mokuai_name,mokuais.reason AS mokuai_reason,
            issues.assigned_to_id,projects.name as projectname,projects.category as categoryname,users.orgNm AS deptname,users.firstname AS username,'' AS opts,'[]' AS cons,
            #{format_time_to_normal("AVG(TIMESTAMPDIFF(SECOND,(CASE WHEN journal_details.prop_key = 'status_id' AND journal_details.value = #{IssueStatus::ASSIGNED_STATUS} THEN journals.created_on ELSE NOW() END),NOW()))")} AS amount").
    joins_with_details("").
    where("((journal_details.prop_key = 'status_id' AND journal_details.value = #{IssueStatus::ASSIGNED_STATUS}) OR (journal_details.prop_key = 'status_id' AND journal_details.old_value = #{IssueStatus::ASSIGNED_STATUS})) AND #{sql || '1=1'}").
    group("#{group_by || 'issues.assigned_to_id'}").having("amount >= 0").
    order("#{order || 'amount desc'}")
  }

  scope :avg_solved_time, lambda { |sql, group_by, order|
    iss1 = self.avg_solved_time_ids("(journal_details.prop_key = 'status_id' AND journal_details.value = #{IssueStatus::REPAIRED_STATUS})",sql, "issues.id", "issues.id,journals.created_on").to_sql
    iss2 = self.avg_solved_time_ids("(journal_details.prop_key = 'status_id' AND journal_details.old_value = #{IssueStatus::REPAIRED_STATUS})",sql, "issues.id", "issues.id,journals.created_on").to_sql
    self.find_by_sql("select GROUP_CONCAT(DISTINCT issues.id) as ids,issues.assigned_to_id,projects.name as projectname,projects.category as categoryname,users.orgNm AS deptname,users.firstname AS username,'' AS opts,'[]' AS cons,
      mokuais.name as mokuai_name,mokuais.reason as mokuai_reason,
      #{format_time_to_normal('AVG(TIMESTAMPDIFF(SECOND,iss1.times,iss2.times))')} as amount from (#{iss1}) as iss1
      inner join issues on iss1.ids = issues.id
      inner join (#{iss2}) as iss2 on iss2.ids = issues.id
      inner join users on users.id = issues.assigned_to_id
      inner join depts on users.orgNo = depts.orgNo
      inner join projects on issues.project_id = projects.id
      inner join mokuais on mokuais.id = issues.mokuai_name
      group by #{group_by || 'ids'}")
  }

  scope :avg_solved_time_ids, lambda { |cons, sql, group_by, order|
    select("GROUP_CONCAT(DISTINCT issues.id) as ids,issues.assigned_to_id,projects.name as projectname,projects.category as categoryname,users.orgNm AS deptname,users.firstname AS username,'' AS opts,'[]' AS cons,
            SUBSTRING_INDEX(GROUP_CONCAT(DISTINCT CASE WHEN #{cons} THEN journals.created_on END),',',1) AS times").
    joins_with_details("").
    where("issues.status_id IN (#{IssueStatus::SOLVED_STATUS}) AND #{cons} AND #{sql.blank? ? '1=1' : sql}").
    group("#{group_by || 'issues.assigned_to_id'}").
    order("#{order || 'amount desc'}")
  }

  scope :avg_walk_time, lambda { |sql, group_by, order|
    table = JournalDetail.avg_walk_time(sql, "issues.id", order).to_sql
    self.find_by_sql("select ids,ymd,ym,issues.assigned_to_id,projectname,categoryname,deptname,username,
      mokuais.name as mokuai_name,mokuais.reason as mokuai_reason,opts,cons,#{format_time_to_normal("AVG(amount)")} AS amount from (
      SELECT
          GROUP_CONCAT(DISTINCT issues.id) AS ids,
          DATE_FORMAT(issues.created_on,'%Y%m%d') AS ymd,
          DATE_FORMAT(issues.created_on,'%Y%m') AS ym,
          issues.assigned_to_id,
          projects.name         AS projectname,
          projects.category     AS categoryname,
          users.orgNm           AS deptname,
          users.firstname       AS username,
          ''                    AS opts,
          '[]'                  AS cons,
          (SUM(TIMESTAMPDIFF(SECOND,(CASE WHEN journal_details.prop_key = 'status_id' AND journal_details.value = #{IssueStatus::REPAIRED_STATUS} THEN journals.created_on ELSE NOW() END),NOW())) - SUM(TIMESTAMPDIFF(SECOND,(CASE WHEN journal_details.prop_key = 'status_id' AND journal_details.value = #{IssueStatus::VERIFICATED_STATUS} THEN journals.created_on ELSE NOW() END),NOW()))) AS amount
        FROM `journal_details`
          LEFT JOIN journals
            ON journals.id = journal_details.journal_id
          LEFT JOIN issues
            ON issues.id = journals.journalized_id
          LEFT JOIN projects
            ON issues.project_id = projects.id
          LEFT JOIN users
            ON users.id = issues.assigned_to_id
          LEFT JOIN depts
            ON depts.orgNo = users.orgNo
        WHERE issues.id in (select ids from (#{table}) as iss)
        GROUP BY issues.id) as issue
        INNER JOIN issues ON issues.id = issue.ids
        INNER JOIN users ON users.id = issues.assigned_to_id
        INNER JOIN depts ON depts.orgNo = users.orgNo
        INNER JOIN projects ON issues.project_id = projects.id
        INNER JOIN mokuais on mokuais.id = issues.mokuai_name
        group by #{group_by}")
  }

  scope :avg_verificate_time, lambda { |sql, group_by, order|
    table = self.avg_verificate_time_issues(sql,nil,"issues.id,journals.created_on").to_sql
    find_by_sql("select ids,issues.assigned_to_id,projectname,categoryname,deptname,username,issue.mokuai_name,issue.mokuai_reason,opts,cons,#{format_time_to_normal("AVG(amount)")} as amount
      from (#{table}) as issue inner join issues on issue.ids = issues.id inner join users on users.id = issues.assigned_to_id
      inner join depts on depts.orgNo = users.orgNo inner join projects on issues.project_id = projects.id
      group by #{group_by || 'issues.assigned_to_id'} order by deptname,username,amount")
  }

  scope :avg_verificate_time_issues, lambda { |sql, group_by, order|
    select("GROUP_CONCAT(issues.id) as ids,issues.assigned_to_id,projects.name as projectname,projects.category as categoryname,users.orgNm AS deptname,mokuais.name AS mokuai_name,mokuais.reason AS mokuai_reason,
      users.firstname AS username,'[]' as cons,'' AS opts,TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(GROUP_CONCAT(journals.created_on),',',1),SUBSTRING_INDEX(GROUP_CONCAT(journals.created_on),',',-1)) AS amount").
    joins_with_details("").
    where("issues.status_id = #{IssueStatus::CLOSE_STATUS} AND (journal_details.prop_key = 'status_id' AND journal_details.value IN (#{IssueStatus::SOLVED_STATUS})) AND #{sql.blank? ? '1=1' : sql}").
    group("#{group_by || 'issues.id'}").having("amount > 0").
    order("#{order || 'amount desc'}")
  }

  scope :verificate_time_personalize, lambda { |sql, group_by, order|
    find_by_sql("SELECT iss1.iid,iss1.username,iss1.deptname,#{format_time_to_normal("TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(iss1.times,',',-1),SUBSTRING_INDEX(iss2.times,',',-1))")} AS amount FROM (
        SELECT
          issues.id       AS iid,
          users.orgNm     AS deptname,
          users.firstname AS username,
          GROUP_CONCAT(journals.created_on) AS times
        FROM `issues`
          INNER JOIN users
            ON users.id = issues.author_id
          INNER JOIN depts
            ON depts.orgNo = users.orgNo
          LEFT JOIN journals
            ON journals.journalized_id = issues.id
          LEFT JOIN journal_details
            ON journal_details.journal_id = journals.id
        WHERE (#{sql.blank? ? '1=1' : sql} AND issues.status_id = #{IssueStatus::CLOSE_STATUS} AND journal_details.prop_key = 'status_id' AND journal_details.value = #{IssueStatus::VERIFICATED_STATUS} AND issues.by_tester = 1)
        GROUP BY issues.id
        ORDER BY issues.id,journals.created_on) AS iss1
        INNER JOIN (
        SELECT
          issues.id       AS iid,
          users.orgNm     AS deptname,
          users.firstname AS username,
          GROUP_CONCAT(journals.created_on) AS times
        FROM `issues`
          INNER JOIN users
            ON users.id = issues.author_id
          INNER JOIN depts
            ON depts.orgNo = users.orgNo
          LEFT JOIN journals
            ON journals.journalized_id = issues.id
          LEFT JOIN journal_details
            ON journal_details.journal_id = journals.id
        WHERE (#{sql.blank? ? '1=1' : sql} AND issues.status_id = #{IssueStatus::CLOSE_STATUS} AND journal_details.prop_key = 'status_id' AND journal_details.value = #{IssueStatus::CLOSE_STATUS} AND issues.by_tester = 1)
        GROUP BY issues.id
        ORDER BY issues.id,journals.created_on
        ) AS iss2 ON iss1.iid = iss2.iid")
  }

  scope :analyze_time, lambda { |sql|
    select("issues.id AS iid,DATE_FORMAT(issues.created_on,'%Y%m%d') AS ymd,DATE_FORMAT(issues.created_on,'%Y%m') AS ym,
        (CASE WHEN journal_details.prop_key = 'assigned_to_id' THEN '指派' WHEN journal_details.prop_key = 'status_id' THEN '状态' END) AS record,depts.orgNm AS deptname,journal_details.value AS assigned_to_id,projects.name as projectname,projects.category as categoryname,
        jnluser.firstname AS statusname,olduser.firstname AS fromname,curuser.firstname AS toname,oldstatus.name AS oldsts,curstatus.name AS cursts,journals.created_on AS assigned_time").
    joins("LEFT JOIN journals
          ON journals.journalized_id = issues.id
        LEFT JOIN journal_details
          ON journals.id = journal_details.journal_id
        LEFT JOIN users AS olduser
          ON olduser.id = journal_details.old_value
            AND journal_details.prop_key = 'assigned_to_id'
        LEFT JOIN users AS curuser
          ON curuser.id = journal_details.value
            AND journal_details.prop_key = 'assigned_to_id'
        LEFT JOIN users AS jnluser
          ON jnluser.id = journals.user_id
        LEFT JOIN issue_statuses AS oldstatus
          ON journal_details.old_value = oldstatus.id
            AND journal_details.prop_key = 'status_id'
        LEFT JOIN issue_statuses AS curstatus
          ON journal_details.value = curstatus.id
            AND journal_details.prop_key = 'status_id'
        LEFT JOIN depts ON curuser.orgNo = depts.orgNo
        LEFT JOIN projects ON projects.id = issues.project_id").
    where("#{sql.blank? ? '1=1' : sql} AND issues.status_id IN (#{IssueStatus::SOLVED_STATUS}) AND (journal_details.prop_key = 'assigned_to_id' OR journal_details.prop_key = 'status_id')").
    order("issues.id,journals.created_on")
  }

  # scope :analyze_time,lambda{|sql|
  #   select("issues.id AS iid,DATE_FORMAT(issues.created_on,'%Y%m%d') AS ymd,DATE_FORMAT(issues.created_on,'%Y%m') AS ym,
  #       depts.orgNm AS deptname,journal_details.value AS assigned_to_id,projects.name as projectname,projects.category as categoryname,
  #       users.firstname AS username,journal_details.old_value,journal_details.value,journals.user_id,journals.created_on").
  #   joins("LEFT JOIN journals
  #            ON journals.id = journal_details.journal_id
  #          LEFT JOIN issues
  #            ON issues.id = journals.journalized_id
  #          LEFT JOIN projects
  #            ON issues.project_id = projects.id
  #          LEFT JOIN users
  #            ON users.id = issues.assigned_to_id
  #          LEFT JOIN depts
  #            ON depts.orgNo = users.orgNo").
  #   where("#{sql.blank? ? '1=1' : sql} AND issues.status_id IN (#{IssueStatus::SOLVED_STATUS}) AND (journal_details.prop_key = 'assigned_to_id' OR journal_details.prop_key = 'status_id')").
  #   order("issues.id,journals.created_on")
  # }

  scope :leave_times_and_rate, lambda { |sql, group_by, order|
    select("issues.id,CASE WHEN assigned_to_id IS NULL THEN 0 ELSE assigned_to_id END AS assigned_to_id,users.firstname AS username,users.orgNm AS deptname,projects.name as projectname,projects.category as categoryname,
            SUBSTRING_INDEX(GROUP_CONCAT(DISTINCT CASE WHEN journal_details.prop_key = 'assigned_to_id' AND journal_details.value = issues.assigned_to_id THEN journals.created_on ELSE issues.updated_on END),',',-1) AS times").
    joins("LEFT JOIN users ON users.id = issues.assigned_to_id
           LEFT JOIN depts ON users.orgNo = depts.orgNo
           LEFT JOIN projects ON issues.project_id = projects.id
           LEFT JOIN journals ON journals.journalized_id = issues.id
           LEFT JOIN journal_details ON journal_details.journal_id = journals.id").
    where("#{sql.blank? ? '1=1' : sql}").
    group("#{group_by || 'issues.id'}").
    order("#{order || 'amount desc'}")
  }

  scope :analysis_timeout, lambda { |sql, order|
    table = self.analysis_timeout_10_days(sql,order).to_sql
    "select issues.id AS iid,users.orgNm AS deptname,users.firstname AS username,juser.id as juser_id,juser.firstname AS jusername,journals.created_on,DATE_FORMAT(issues.created_on,'%Y%m') AS mon
     from issues INNER JOIN (#{table}) as iss ON issues.id = iss.id
     LEFT JOIN journals ON journals.journalized_id = issues.id
     LEFT JOIN journal_details ON journal_details.journal_id = journals.id
     INNER JOIN users ON journal_details.prop_key = 'assigned_to_id' AND users.id = journal_details.value
     INNER JOIN users AS juser ON juser.id = journals.user_id"
  }

  scope :analysis_timeout_10_days, lambda { |sql, order|
    select("issues.id").
    joins("LEFT JOIN journals ON journals.journalized_id = issues.id
           LEFT JOIN journal_details ON journal_details.journal_id = journals.id").
    where("issues.status_id IN (#{IssueStatus::SOLVED_STATUS}) AND ((journal_details.prop_key = 'status_id' AND journal_details.old_value = 7) OR (journal_details.prop_key = 'status_id' AND journal_details.value = 11)) AND #{sql}").
    group("issues.id").
    having("FIND_IN_SET('7',GROUP_CONCAT(journal_details.old_value)) AND FIND_IN_SET('11',GROUP_CONCAT(journal_details.value))
            AND TIMESTAMPDIFF(SECOND,SUBSTRING_INDEX(GROUP_CONCAT(journals.created_on),',',1),SUBSTRING_INDEX(GROUP_CONCAT(journals.created_on),',',-1)) > 10*24*3600").
    order("#{order || 'issues.id'}")
  }

  scope :leave_amount_and_solved_rate, lambda { |sql, group_by, order|
    feilds = []
    IssuePriority.active.each do |pb|
      CustomField.visible.find_by_name("概率").possible_values.each do |gl|
        gl_name = case gl when "必现" then "b" when "随机" then "s" when "单机必现" then "d" end
        fd_name = pb.name.to_s.split('-')[0].downcase + gl_name
        fd_con = "SUM(CASE WHEN probability.name = '#{pb.name}' AND cf2.value = '#{gl}'"
        fd_solved = "issues.status_id IN (#{IssueStatus::SOLVED_STATUS})"
        fd_unsolved = "issues.status_id IN (#{IssueStatus::ANALYSIS_STATUS + ',' + IssueStatus::LEAVE_STATUS})"
        feilds << "#{fd_con} AND #{fd_solved} THEN 1 ELSE 0 END) AS #{fd_name}s"
        feilds << "#{fd_con} AND #{fd_unsolved} THEN 1 ELSE 0 END) AS #{fd_name}u"
        feilds << "ROUND(IFNULL(#{fd_con} AND DATE_FORMAT(issues.created_on,'%Y%m%d') <> DATE_FORMAT(NOW(),'%Y%m%d') AND #{fd_solved} THEN 1 ELSE 0 END) /
            #{fd_con} AND DATE_FORMAT(issues.created_on,'%Y%m%d') <> DATE_FORMAT(NOW(),'%Y%m%d') AND #{fd_unsolved} THEN 1 ELSE 0 END),0),2) AS #{fd_name}_today"
        feilds << "ROUND(IFNULL(#{fd_con} AND (TO_DAYS(NOW()) - TO_DAYS(issues.created_on)) > 1 AND #{fd_solved} THEN 1 ELSE 0 END) /
            #{fd_con} AND (TO_DAYS(NOW()) - TO_DAYS(issues.created_on)) > 1 AND issues.status_id IN (#{IssueStatus::SOLVED_STATUS + ',' + IssueStatus::ANALYSIS_STATUS + ',' + IssueStatus::UNSOLVED_STATUS}) THEN 1 ELSE 0 END),0),2) AS #{fd_name}_yesterday"
      end
    end

    select(feilds.join(',')).joins_without_details("").where("#{sql}").group(group_by || "issues.project_id").order(order || "projects.created_on desc")
  }

  scope :bug_moving_and_back_to_owner,lambda { |sql,group_by,order|
    ids = Array.wrap(self.moving_and_back_to_owner_bugs(sql,group_by,order)).map(&:id).join(',')
    select("issues.id AS iid,issues.subject,cur.firstname AS username,oldur.firstname AS jusername,DATE_FORMAT(issues.updated_on,'%Y-%m-%d %H:%i:%s') AS updated_dt,
      cast(journals.notes as char) AS markpoint,journal_details.value as cuvalue,journal_details.old_value as oldvalue").
    joins_with_details("INNER JOIN users AS cur ON journal_details.value = cur.id AND journal_details.prop_key = 'assigned_to_id'
                        INNER JOIN users AS oldur ON journal_details.old_value = oldur.id AND journal_details.prop_key = 'assigned_to_id'").
    where("journal_details.prop_key = 'assigned_to_id' and journal_details.value is not null and journal_details.old_value is not null and issues.id in (#{ids.blank? ? 0 : ids}) and #{sql || '1=1'}")
  }

  scope :moving_and_back_to_owner_bugs,lambda { |sql,group_by,order|
    select("issues.id").
    joins_with_details("INNER JOIN users AS juser ON journals.user_id = juser.id AND journal_details.prop_key = 'assigned_to_id'").
    where("journal_details.prop_key = 'assigned_to_id' and #{sql || '1=1'}").
    group(group_by || "issues.id").
    having("COUNT(journal_details.id) > 3").
    order(order || "issues.id,journals.created_on,projects.created_on desc")
  }

  scope :bug_moving_time, lambda { |start_dt,end_dt,status_ids,assigned_ids,sql|
    status = self.bug_moving_time_with_status(start_dt,end_dt,status_ids,sql)
    assigned = self.bug_moving_time_with_assigned_to(start_dt,end_dt,assigned_ids,sql)
    self.find_by_sql("select * from (#{status} union #{assigned}) as issue order by 问题ID,状态更新时间")
  }

  scope :bug_moving_time_with_status, lambda { |bdt,edt,sids,sql|
    "(SELECT ifnull(ls_status.name,'') AS '所有状态',issues.id AS '问题ID',
      projects.name AS '项目',DATE_FORMAT(issues.created_on,'%Y-%m-%d %H:%m:%s') AS '状态更新时间',
      author.firstname AS '状态操作者',ifnull(assigned.firstname,'') AS '指派者','' AS '历史指派给',
      ifnull(cf2.value,'') AS '概率',ifnull(cf3.value,'') AS '解决版本',ifnull(cf13.value,'') AS '验证版本',
      ifnull(cf11.value,'') AS '通过E-consulter分析',ifnull(cf12.value,'') AS '研发分析结论',
      ifnull(cf5.value,'') AS '类型',mokuais.name AS '模块',author.firstname AS '作者',
      ifnull(assigned.orgNm,'') AS '指派者部门',ifnull(issues.description,'') AS '备注'
    FROM issues
    LEFT JOIN journals ON issues.id = journals.journalized_id
    LEFT JOIN journal_details ON journal_details.journal_id = journals.id
    LEFT JOIN projects ON projects.id = issues.project_id
    LEFT JOIN users AS assigned ON assigned.id = issues.assigned_to_id
    LEFT JOIN depts ON depts.orgNo = assigned.orgNo
    LEFT JOIN users AS author ON author.id = issues.author_id
    LEFT JOIN mokuais ON issues.mokuai_name = mokuais.id
    LEFT JOIN issue_statuses AS ls_status ON journal_details.old_value = ls_status.id AND journal_details.prop_key = 'status_id'
    LEFT JOIN custom_values AS cf2 ON cf2.customized_id = issues.id AND cf2.custom_field_id = 2 AND cf2.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf3 ON cf3.customized_id = issues.id AND cf3.custom_field_id = 3 AND cf3.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf5 ON cf5.customized_id = issues.id AND cf5.custom_field_id = 5 AND cf5.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf11 ON cf11.customized_id = issues.id AND cf11.custom_field_id = 11 AND cf11.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf12 ON cf12.customized_id = issues.id AND cf12.custom_field_id = 12 AND cf12.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf13 ON cf13.customized_id = issues.id AND cf13.custom_field_id = 13 AND cf13.customized_type = 'Issue'
    WHERE issues.created_on > '#{bdt} 00:00:00' AND issues.created_on < '#{edt} 23:59:59' AND #{sql || '1=1'}
      AND journal_details.prop_key = 'status_id' AND journal_details.old_value > 0 #{sids.blank? || sids.to_s == 'null' ? "" : "AND journal_details.old_value in (#{sids})"}
    GROUP BY issues.id
    ORDER BY journals.created_on,issues.id)
    UNION
    (SELECT ifnull(cu_status.name,'') AS '所有状态',issues.id AS '问题ID',
      projects.name AS '项目',DATE_FORMAT(issues.created_on,'%Y-%m-%d %H:%m:%s') AS '状态更新时间',
      author.firstname AS '状态操作者',ifnull(assigned.firstname,'') AS '指派者','' AS '历史指派给',
      ifnull(cf2.value,'') AS '概率',ifnull(cf3.value,'') AS '解决版本',ifnull(cf13.value,'') AS '验证版本',
      ifnull(cf11.value,'') AS '通过E-consulter分析',ifnull(cf12.value,'') AS '研发分析结论',
      ifnull(cf5.value,'') AS '类型',mokuais.name AS '模块',author.firstname AS '作者',
      ifnull(assigned.orgNm,'') AS '指派者部门',ifnull(issues.description,'') AS '备注'
    FROM issues
    LEFT JOIN journals ON issues.id = journals.journalized_id
    LEFT JOIN journal_details ON journal_details.journal_id = journals.id
    LEFT JOIN projects ON projects.id = issues.project_id
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
    LEFT JOIN custom_values AS cf13 ON cf13.customized_id = issues.id AND cf13.custom_field_id = 13 AND cf13.customized_type = 'Issue'
    WHERE issues.created_on > '#{bdt} 00:00:00' AND issues.created_on < '#{edt} 23:59:59'
      AND #{sql || '1=1'} #{sids.blank? || sids.to_s == 'null' ? "" : "AND issues.status_id in (#{sids})"}
    GROUP BY issues.id
    HAVING IFNULL(FIND_IN_SET('status_id',GROUP_CONCAT(journal_details.prop_key)),0) = 0
    ORDER BY issues.id,journals.created_on)
    UNION
    (SELECT ifnull(cu_status.name,'') AS '所有状态',issues.id AS '问题ID',
      projects.name AS '项目',DATE_FORMAT(journals.created_on,'%Y-%m-%d %H:%m:%s') AS '状态更新时间',
      jourer.firstname AS '状态操作者',ifnull(assigned.firstname,'') AS '指派者','' AS '历史指派给',
      ifnull(cf2.value,'') AS '概率',ifnull(cf3.value,'') AS '解决版本',ifnull(cf13.value,'') AS '验证版本',
      ifnull(cf11.value,'') AS '通过E-consulter分析',ifnull(cf12.value,'') AS '研发分析结论',
      ifnull(cf5.value,'') AS '类型',mokuais.name AS '模块',author.firstname AS '作者',
      ifnull(assigned.orgNm,'') AS '指派者部门',ifnull(issues.description,'') AS '备注'
    FROM issues
    LEFT JOIN journals ON issues.id = journals.journalized_id
    LEFT JOIN journal_details ON journal_details.journal_id = journals.id
    LEFT JOIN projects ON projects.id = issues.project_id
    LEFT JOIN users AS jourer ON jourer.id = journals.user_id
    LEFT JOIN users AS assigned ON assigned.id = issues.assigned_to_id
    LEFT JOIN depts ON depts.orgNo = assigned.orgNo
    LEFT JOIN users AS author ON author.id = issues.author_id
    LEFT JOIN mokuais ON issues.mokuai_name = mokuais.id
    LEFT JOIN issue_statuses AS ls_status ON journal_details.old_value = ls_status.id AND journal_details.prop_key = 'status_id'
    LEFT JOIN issue_statuses AS cu_status ON journal_details.value = cu_status.id AND journal_details.prop_key = 'status_id'
    LEFT JOIN custom_values AS cf2 ON cf2.customized_id = issues.id AND cf2.custom_field_id = 2 AND cf2.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf3 ON cf3.customized_id = issues.id AND cf3.custom_field_id = 3 AND cf3.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf5 ON cf5.customized_id = issues.id AND cf5.custom_field_id = 5 AND cf5.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf11 ON cf11.customized_id = issues.id AND cf11.custom_field_id = 11 AND cf11.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf12 ON cf12.customized_id = issues.id AND cf12.custom_field_id = 12 AND cf12.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf13 ON cf13.customized_id = issues.id AND cf13.custom_field_id = 13 AND cf13.customized_type = 'Issue'
    WHERE journals.created_on > '#{bdt} 00:00:00' AND journals.created_on < '#{edt} 23:59:59' AND #{sql || '1=1'}
      AND journal_details.prop_key = 'status_id' #{sids.blank? || sids.to_s == 'null' ? "" : "AND journal_details.value in (#{sids})"})"
  }

  scope :bug_moving_time_with_assigned_to, lambda { |bdt,edt,aids,sql|
    "(SELECT '' AS '所有状态',issues.id AS '问题ID',projects.name AS '项目',DATE_FORMAT(issues.created_on,'%Y-%m-%d %H:%m:%s') AS '更新时间',
      author.firstname AS '状态操作者',ifnull(assigned.firstname,'') AS '指派者',ifnull(ls_assigned.firstname,'') AS '历史指派给',
      ifnull(cf2.value,'') AS '概率',ifnull(cf3.value,'') AS '解决版本',ifnull(cf13.value,'') AS '验证版本',
      ifnull(cf11.value,'') AS '通过E-consulter分析',ifnull(cf12.value,'') AS '研发分析结论',
      ifnull(cf5.value,'') AS '类型',mokuais.name AS '模块',author.firstname AS '作者',
      ifnull(assigned.orgNm,'') AS '指派者部门',ifnull(issues.description,'') AS '备注'
    FROM issues
    LEFT JOIN journals ON issues.id = journals.journalized_id
    LEFT JOIN journal_details ON journal_details.journal_id = journals.id
    LEFT JOIN projects ON projects.id = issues.project_id
    LEFT JOIN users AS assigned ON assigned.id = issues.assigned_to_id
    LEFT JOIN depts ON depts.orgNo = assigned.orgNo
    LEFT JOIN users AS author ON author.id = issues.author_id
    LEFT JOIN mokuais ON issues.mokuai_name = mokuais.id
    LEFT JOIN users AS ls_assigned ON journal_details.old_value = ls_assigned.id AND journal_details.prop_key = 'assigned_to_id'
    LEFT JOIN custom_values AS cf2 ON cf2.customized_id = issues.id AND cf2.custom_field_id = 2 AND cf2.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf3 ON cf3.customized_id = issues.id AND cf3.custom_field_id = 3 AND cf3.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf5 ON cf5.customized_id = issues.id AND cf5.custom_field_id = 5 AND cf5.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf11 ON cf11.customized_id = issues.id AND cf11.custom_field_id = 11 AND cf11.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf12 ON cf12.customized_id = issues.id AND cf12.custom_field_id = 12 AND cf12.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf13 ON cf13.customized_id = issues.id AND cf13.custom_field_id = 13 AND cf13.customized_type = 'Issue'
    WHERE issues.created_on > '#{bdt} 00:00:00' AND issues.created_on < '#{edt} 23:59:59' AND #{sql || '1=1'}
      AND journal_details.prop_key = 'assigned_to_id' AND journal_details.old_value > 0 #{aids.blank? || aids.to_s == 'null' ? "" : "AND journal_details.old_value in (#{aids})"}
    GROUP BY issues.id
    ORDER BY journals.created_on,issues.id)
    UNION
    (SELECT '' AS '所有状态',issues.id AS '问题ID',projects.name AS '项目',DATE_FORMAT(issues.created_on,'%Y-%m-%d %H:%m:%s') AS '更新时间',
      author.firstname AS '状态操作者',ifnull(assigned.firstname,'') AS '指派者',ifnull(assigned.firstname,'') AS '历史指派给',
      ifnull(cf2.value,'') AS '概率',ifnull(cf3.value,'') AS '解决版本',ifnull(cf13.value,'') AS '验证版本',
      ifnull(cf11.value,'') AS '通过E-consulter分析',ifnull(cf12.value,'') AS '研发分析结论',
      ifnull(cf5.value,'') AS '类型',mokuais.name AS '模块',author.firstname AS '作者',
      ifnull(assigned.orgNm,'') AS '指派者部门',ifnull(issues.description,'') AS '备注'
    FROM issues
    LEFT JOIN journals ON issues.id = journals.journalized_id
    LEFT JOIN journal_details ON journal_details.journal_id = journals.id
    LEFT JOIN projects ON projects.id = issues.project_id
    LEFT JOIN users AS assigned ON assigned.id = issues.assigned_to_id
    LEFT JOIN depts ON depts.orgNo = assigned.orgNo
    LEFT JOIN users AS author ON author.id = issues.author_id
    LEFT JOIN mokuais ON issues.mokuai_name = mokuais.id
    LEFT JOIN custom_values AS cf2 ON cf2.customized_id = issues.id AND cf2.custom_field_id = 2 AND cf2.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf3 ON cf3.customized_id = issues.id AND cf3.custom_field_id = 3 AND cf3.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf5 ON cf5.customized_id = issues.id AND cf5.custom_field_id = 5 AND cf5.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf11 ON cf11.customized_id = issues.id AND cf11.custom_field_id = 11 AND cf11.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf12 ON cf12.customized_id = issues.id AND cf12.custom_field_id = 12 AND cf12.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf13 ON cf13.customized_id = issues.id AND cf13.custom_field_id = 13 AND cf13.customized_type = 'Issue'
    WHERE issues.created_on > '#{bdt} 00:00:00' AND issues.created_on < '#{edt} 23:59:59'
      AND #{sql || '1=1'} #{aids.blank? || aids.to_s == 'null' ? "" : "AND issues.assigned_to_id in (#{aids})"}
    GROUP BY issues.id
    HAVING IFNULL(FIND_IN_SET('assigned_to_id',GROUP_CONCAT(journal_details.prop_key)),0) = 0
    ORDER BY issues.id,journals.created_on)
    UNION
    (SELECT '' AS '所有状态',issues.id AS '问题ID',projects.name AS '项目',DATE_FORMAT(journals.created_on,'%Y-%m-%d %H:%m:%s') AS '状态更新时间',
      jourer.firstname AS '状态操作者',ifnull(assigned.firstname,'') AS '指派者',ifnull(ls_assigned.firstname,'') AS '历史指派给',
      ifnull(cf2.value,'') AS '概率',ifnull(cf3.value,'') AS '解决版本',ifnull(cf13.value,'') AS '验证版本',
      ifnull(cf11.value,'') AS '通过E-consulter分析',ifnull(cf12.value,'') AS '研发分析结论',
      ifnull(cf5.value,'') AS '类型',mokuais.name AS '模块',author.firstname AS '作者',
      ifnull(assigned.orgNm,'') AS '指派者部门',ifnull(issues.description,'') AS '备注'
    FROM issues
    LEFT JOIN journals ON issues.id = journals.journalized_id
    LEFT JOIN journal_details ON journal_details.journal_id = journals.id
    LEFT JOIN projects ON projects.id = issues.project_id
    LEFT JOIN users AS jourer ON jourer.id = journals.user_id
    LEFT JOIN users AS assigned ON assigned.id = issues.assigned_to_id
    LEFT JOIN depts ON depts.orgNo = assigned.orgNo
    LEFT JOIN users AS author ON author.id = issues.author_id
    LEFT JOIN mokuais ON issues.mokuai_name = mokuais.id
    LEFT JOIN users AS ls_assigned ON journal_details.old_value = ls_assigned.id AND journal_details.prop_key = 'assigned_to_id'
    LEFT JOIN custom_values AS cf2 ON cf2.customized_id = issues.id AND cf2.custom_field_id = 2 AND cf2.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf3 ON cf3.customized_id = issues.id AND cf3.custom_field_id = 3 AND cf3.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf5 ON cf5.customized_id = issues.id AND cf5.custom_field_id = 5 AND cf5.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf11 ON cf11.customized_id = issues.id AND cf11.custom_field_id = 11 AND cf11.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf12 ON cf12.customized_id = issues.id AND cf12.custom_field_id = 12 AND cf12.customized_type = 'Issue'
    LEFT JOIN custom_values AS cf13 ON cf13.customized_id = issues.id AND cf13.custom_field_id = 13 AND cf13.customized_type = 'Issue'
    WHERE journals.created_on > '#{bdt} 00:00:00' AND journals.created_on < '#{edt} 23:59:59' AND #{sql || '1=1'}
      AND journal_details.prop_key = 'assigned_to_id' #{aids.blank? || aids.to_s == 'null' ? "" : "AND journal_details.value in (#{aids})"})"
  }

  scope :caijue, lambda{
    where("status_id = 20 AND (umpire_id = #{User.current.id} #{User.current.admin? ? 'OR umpire_id IS NULL' : ''})")
  }

  before_validation :clear_disabled_fields
  before_create :default_assign
  before_save :change_copies_status, :update_done_ratio_from_issue_status, :update_mokuai_when_close,
              :force_updated_on_change, :update_closed_on, :update_start_or_due_date, :set_assigned_to_was
  after_save { |issue| issue.send :after_project_change if !issue.id_changed? && issue.project_id_changed? }
  after_save :reschedule_following_issues, :update_nested_set_attributes,
             :update_parent_attributes, :create_journal, :check_subject_wildcards, :to_do_when_status_changed
  # Should be after_create but would be called before previous after_save callbacks
  after_save :after_create_from_copy
  after_destroy :update_parent_attributes
  after_create :send_notification, :refresh_issues_redis_cache
  # Keep it at the end of after_save callbacks
  after_save :clear_assigned_to_was
  after_save :merge_update_closed_on_and_due_date_incase

  def self.show_feilds_by_group(groupby = "issues.assigned_to_id")
    feilds = "GROUP_CONCAT(DISTINCT issues.id) as ids,issues.assigned_to_id,projects.id as pId,projects.name as projectname,projects.category as categoryname,"
    feilds << case groupby
                when "issues.assigned_to_id" then
                  "depts.id as dId,users.orgNm AS deptname,users.id as uId,users.firstname AS username"
                when "users.orgNm" then
                  "depts.id as dId,users.orgNm AS deptname,'' as uId,'' AS username"
                when "issues.project_id" then
                  "'' as dId,'' AS deptname,'' as uId,'' AS username"
                when "projects.category" then
                  "depts.id as dId,users.orgNm AS deptname,users.id as uId,users.firstname AS username"
                when "issues.mokuai_name" then
                  "'' as dId,'' AS deptname,'' as uId,'' AS username,mokuais.name AS mokuai_name"
                when "issues.mokuai_reason" then
                  "'' as dId,'' AS deptname,'' as uId,'' AS username,mokuais.reason AS mokuai_reason"
                else
                  "depts.id as dId,users.orgNm AS deptname,users.id as uId,users.firstname AS username"
              end
    feilds
  end

  def self.show_feilds_by_group_mokuai(groupby = "issues.assigned_to_id")
    feilds = "ids,assigned_to_id,pId,projectname,categoryname,SUM(amount) AS amount,"
    feilds << case groupby
                when "issues.assigned_to_id" then
                  "dId,deptname,uId,username"
                when "users.orgNm" then
                  "dId,deptname,uId,username"
                when "issues.project_id" then
                  "dId,deptname,uId,username"
                when "projects.category" then
                  "dId,deptname,uId,username"
                when "issues.mokuai_name" then
                  "dId,deptname,uId,username,mokuai_name"
                when "issues.mokuai_reason" then
                  "dId,deptname,uId,username,mokuai_reason"
                else
                  "dId,deptname,uId,username"
              end
    feilds
  end

  def self.group_by_group(groupby)
    groupby = groupby || 'issues.assigned_to_id'
    case groupby
      when "issues.assigned_to_id" then
        "assigned_to_id"
      when "users.orgNm" then
        "dId"
      when "issues.project_id" then
        "pId"
      when "issues.mokuai_name" then
        "mokuai_name"
      when "issues.mokuai_reason" then
        "mokuai_reason"
    end
  end

  # Pick up assigned to by the time
  # Case when issue has no journals then pick up the assigned to of the issue
  # Case when journal_details value is nearly the time then pick the value else pick up the old_value after the time
  def pick_up_by_time(property ,prop_key, time)
    issue = Issue.find(self.id)
    isu = {:id => issue.id}

    if issue.present?
      journals = issue.journals
      if issue.created_on <= time
        if journals.blank?
          isu[:created_on] = issue.created_on.to_s(:db)
          if property == "cf"
            isu[(property.to_s + prop_key.to_s).to_sym] = issue.probability if issue.probability
          else
            isu[prop_key.to_sym] = issue.send(prop_key.to_s) if issue.send(prop_key.to_s)
          end
        else
          sql = "issues.id = #{issue.id} and property = '#{property}' and prop_key = '#{prop_key}'"
          detail = JournalDetail.issue_journal_details("#{sql} and journals.created_on < '#{time}'", nil, "journals.created_on desc").first
          if detail.present?
            isu[:created_on] = detail.jcreated.to_s(:db)
            attr = property == "cf" ? (property.to_s + prop_key.to_s) : prop_key
            isu[attr.to_sym] = detail.value
          else
            detail = JournalDetail.issue_journal_details("#{sql} and journals.created_on > '#{time}'", nil, "journals.created_on").first
            if detail.present?
              isu[:created_on] = detail.jcreated.to_s(:db)
              attr = property == "cf" ? (property.to_s + prop_key.to_s) : prop_key
              isu[attr.to_sym] = detail.old_value
            else
              isu[:created_on] = issue.created_on.to_s(:db)
              if property == "cf"
                isu[(property.to_s + prop_key.to_s).to_sym] = issue.probability if issue.probability
              else
                isu[prop_key.to_s.to_sym] = issue.send(prop_key.to_s) if issue.send(prop_key.to_s)
              end
            end
          end
        end
      end
    end
    isu
  end

  # Returns a SQL conditions string used to find all issues visible by the specified user
  def self.visible_condition(user, options={})
    Project.allowed_to_condition(user, :view_issues, options) do |role, user|
      sql = if user.id && user.logged?
              case role.issues_visibility
                when 'all'
                  '1=1'
                when 'default'
                  user_ids = [user.id] + user.groups.map(&:id).compact
                  "(#{table_name}.is_private = #{connection.quoted_false} OR #{table_name}.author_id = #{user.id} OR #{table_name}.assigned_to_id IN (#{user_ids.join(',')}))"
                when 'own'
                  user_ids = [user.id] + user.groups.map(&:id).compact
                  "(#{table_name}.author_id = #{user.id} OR #{table_name}.assigned_to_id IN (#{user_ids.join(',')}))"
                else
                  '1=0'
              end
            else
              "(#{table_name}.is_private = #{connection.quoted_false})"
            end
      unless role.permissions_all_trackers?(:view_issues)
        tracker_ids = role.permissions_tracker_ids(:view_issues)
        if tracker_ids.any?
          sql = "(#{sql} AND #{table_name}.tracker_id IN (#{tracker_ids.join(',')}))"
        else
          sql = '1=0'
        end
      end
      sql
    end
  end

  # Returns true if usr or current user is allowed to view the issue
  def visible?(usr=nil)
    (usr || User.current).allowed_to?(:view_issues, self.project) do |role, user|
      visible = if user.logged?
                  case role.issues_visibility
                    when 'all'
                      true
                    when 'default'
                      !self.is_private? || (self.author == user || user.is_or_belongs_to?(assigned_to))
                    when 'own'
                      self.author == user || user.is_or_belongs_to?(assigned_to)
                    else
                      false
                  end
                else
                  !self.is_private?
                end
      unless role.permissions_all_trackers?(:view_issues)
        visible &&= role.permissions_tracker_ids?(:view_issues, tracker_id)
      end
      visible
    end
  end

  # Returns true if user or current user is allowed to edit or add notes to the issue
  def editable?(user=User.current)
    attributes_editable?(user) || notes_addable?(user)
  end

  # Returns true if user or current user is allowed to edit the issue
  def attributes_editable?(user=User.current)
    user_tracker_permission?(user, :edit_issues)
  end

  # Overrides Redmine::Acts::Attachable::InstanceMethods#attachments_editable?
  def attachments_editable?(user=User.current)
    attributes_editable?(user)
  end

  # Returns true if user or current user is allowed to add notes to the issue
  def notes_addable?(user=User.current)
    user_tracker_permission?(user, :add_issue_notes)
  end

  # Returns true if user or current user is allowed to delete the issue
  def deletable?(user=User.current)
    user_tracker_permission?(user, :delete_issues)
  end

  def initialize(attributes=nil, *args)
    super
    if new_record?
      # set default values for new records only
      self.priority ||= IssuePriority.default
      self.watcher_user_ids = []
    end
  end

  def create_or_update
    super
  ensure
    @status_was = nil
  end

  private :create_or_update

  # AR#Persistence#destroy would raise and RecordNotFound exception
  # if the issue was already deleted or updated (non matching lock_version).
  # This is a problem when bulk deleting issues or deleting a project
  # (because an issue may already be deleted if its parent was deleted
  # first).
  # The issue is reloaded by the nested_set before being deleted so
  # the lock_version condition should not be an issue but we handle it.
  def destroy
    super
  rescue ActiveRecord::StaleObjectError, ActiveRecord::RecordNotFound
    # Stale or already deleted
    begin
      reload
    rescue ActiveRecord::RecordNotFound
      # The issue was actually already deleted
      @destroyed = true
      return freeze
    end
    # The issue was stale, retry to destroy
    super
  end

  alias :base_reload :reload

  def reload(*args)
    @workflow_rule_by_attribute = nil
    @assignable_versions = nil
    @relations = nil
    @spent_hours = nil
    @total_spent_hours = nil
    @total_estimated_hours = nil
    base_reload(*args)
  end

  # Overrides Redmine::Acts::Customizable::InstanceMethods#available_custom_fields
  def available_custom_fields
    (project && tracker) ? (project.all_issue_custom_fields & tracker.custom_fields) : []
  end

  def visible_custom_field_values(user=nil)
    user_real = user || User.current
    custom_field_values.select do |value|
      value.custom_field.visible_by?(project, user_real)
    end
  end

  # Copies attributes from another issue, arg can be an id or an Issue
  def copy_from(arg, options={})
    issue = arg.is_a?(Issue) ? arg : Issue.visible.find(arg)
    self.attributes = issue.attributes.dup.except("id", "root_id", "parent_id", "lft", "rgt", "created_on", "updated_on")
    self.custom_field_values = issue.custom_field_values.inject({}) { |h, v| h[v.custom_field_id] = v.value; h }
    self.status = issue.status
    self.author = User.current
    unless options[:attachments] == false
      self.attachments = issue.attachments.map do |attachement|
        attachement.copy(:container => self)
      end
    end
    @copied_from = issue
    @copy_options = options
    self
  end

  # Returns an unsaved copy of the issue
  def copy(attributes=nil, copy_options={})
    copy = self.class.new.copy_from(self, copy_options)
    copy.attributes = attributes if attributes
    copy
  end

  # Returns true if the issue is a copy
  def copy?
    @copied_from.present?
  end

  def status_id=(status_id)
    if status_id.to_s != self.status_id.to_s
      self.status = (status_id.present? ? IssueStatus.find_by_id(status_id) : nil)
    end
    self.status_id
  end

  # Sets the status.
  def status=(status)
    if status != self.status
      @workflow_rule_by_attribute = nil
    end
    association(:status).writer(status)
  end

  def priority_id=(pid)
    self.priority = nil
    write_attribute(:priority_id, pid)
  end

  def category_id=(cid)
    self.category = nil
    write_attribute(:category_id, cid)
  end

  def fixed_version_id=(vid)
    self.fixed_version = nil
    write_attribute(:fixed_version_id, vid)
  end

  def tracker_id=(tracker_id)
    if tracker_id.to_s != self.tracker_id.to_s
      self.tracker = (tracker_id.present? ? Tracker.find_by_id(tracker_id) : nil)
    end
    self.tracker_id
  end

  # Sets the tracker.
  # This will set the status to the default status of the new tracker if:
  # * the status was the default for the previous tracker
  # * or if the status was not part of the new tracker statuses
  # * or the status was nil
  def tracker=(tracker)
    tracker_was = self.tracker
    association(:tracker).writer(tracker)
    if tracker != tracker_was
      if status == tracker_was.try(:default_status)
        self.status = nil
      elsif status && tracker && !tracker.issue_status_ids.include?(status.id)
        self.status = nil
      end
      reassign_custom_field_values
      @workflow_rule_by_attribute = nil
    end
    self.status ||= default_status
    self.tracker
  end

  def project_id=(project_id)
    if project_id.to_s != self.project_id.to_s
      self.project = (project_id.present? ? Project.find_by_id(project_id) : nil)
    end
    self.project_id
  end

  # Sets the project.
  # Unless keep_tracker argument is set to true, this will change the tracker
  # to the first tracker of the new project if the previous tracker is not part
  # of the new project trackers.
  # This will:
  # * clear the fixed_version is it's no longer valid for the new project.
  # * clear the parent issue if it's no longer valid for the new project.
  # * set the category to the category with the same name in the new
  #   project if it exists, or clear it if it doesn't.
  # * for new issue, set the fixed_version to the project default version
  #   if it's a valid fixed_version.
  def project=(project, keep_tracker=false)
    project_was = self.project
    association(:project).writer(project)
    if project_was && project && project_was != project
      @assignable_versions = nil

      unless keep_tracker || project.trackers.include?(tracker)
        self.tracker = project.trackers.first
      end
      # Reassign to the category with same name if any
      if category
        self.category = project.issue_categories.find_by_name(category.name)
      end
      # Keep the fixed_version if it's still valid in the new_project
      if fixed_version && fixed_version.project != project && !project.shared_versions.include?(fixed_version)
        self.fixed_version = nil
      end
      # Clear the parent task if it's no longer valid
      unless valid_parent_project?
        self.parent_issue_id = nil
      end
      reassign_custom_field_values
      @workflow_rule_by_attribute = nil
    end
    # Set fixed_version to the project default version if it's valid
    if new_record? && fixed_version.nil? && project && project.default_version_id?
      if project.shared_versions.open.exists?(project.default_version_id)
        self.fixed_version_id = project.default_version_id
      end
    end
    self.project
  end

  def description=(arg)
    if arg.is_a?(String)
      arg = arg.gsub(/(\r\n|\n|\r)/, "\r\n")
    end
    write_attribute(:description, arg)
  end

  # Overrides assign_attributes so that project and tracker get assigned first
  def assign_attributes_with_project_and_tracker_first(new_attributes, *args)
    return if new_attributes.nil?
    attrs = new_attributes.dup
    attrs.stringify_keys!

    %w(project project_id tracker tracker_id).each do |attr|
      if attrs.has_key?(attr)
        send "#{attr}=", attrs.delete(attr)
      end
    end
    send :assign_attributes_without_project_and_tracker_first, attrs, *args
  end

  # Do not redefine alias chain on reload (see #4838)
  alias_method_chain(:assign_attributes, :project_and_tracker_first) unless method_defined?(:assign_attributes_without_project_and_tracker_first)

  def attributes=(new_attributes)
    assign_attributes new_attributes
  end

  def estimated_hours=(h)
    write_attribute :estimated_hours, (h.is_a?(String) ? h.to_hours : h)
  end

  safe_attributes 'project_id',
                  'tracker_id',
                  'status_id',
                  'category_id',
                  'assigned_to_id',
                  'priority_id',
                  'fixed_version_id',
                  'subject',
                  'description',
                  'start_date',
                  'due_date',
                  'done_ratio',
                  'estimated_hours',
                  'custom_field_values',
                  'custom_fields',
                  'lock_version',
                  'notes',
                  'mokuai_reason', # Mokuai Reason Protect
                  'mokuai_name', # Mokuai Name Protect
                  'rom_version', # Rom Version
                  'tfde_id', # TFDE
                  # 'test_emphasis',
                  # 'releate_mokuai',
                  # 'phenomena_category',
                  # 'discovery_version',
                  # 'solve_version',
                  # 'releate_case',
                  # 'verificate_version',
                  # 'releate_quality_case',
                  # 'quality_category',
                  # 'blueprint_issue',
                  # 'back_log',
                  'by_tester',
                  :if => lambda { |issue, user| issue.new_record? || issue.attributes_editable?(user) }

  safe_attributes 'notes',
                  :if => lambda { |issue, user| issue.notes_addable?(user) }

  safe_attributes 'private_notes',
                  :if => lambda { |issue, user| !issue.new_record? && user.allowed_to?(:set_notes_private, issue.project) }

  safe_attributes 'watcher_user_ids',
                  :if => lambda { |issue, user| issue.new_record? && user.allowed_to?(:add_issue_watchers, issue.project) }

  safe_attributes 'is_private',
                  :if => lambda { |issue, user|
                    user.allowed_to?(:set_issues_private, issue.project) ||
                        (issue.author_id == user.id && user.allowed_to?(:set_own_issues_private, issue.project))
                  }

  safe_attributes 'parent_issue_id',
                  :if => lambda { |issue, user| (issue.new_record? || issue.attributes_editable?(user)) &&
                      user.allowed_to?(:manage_subtasks, issue.project) }

  def safe_attribute_names(user=nil)
    names = super
    names -= disabled_core_fields
    names -= read_only_attribute_names(user)
    if new_record?
      # Make sure that project_id can always be set for new issues
      names |= %w(project_id)
    end
    if dates_derived?
      names -= %w(start_date due_date)
    end
    if priority_derived?
      names -= %w(priority_id)
    end
    if done_ratio_derived?
      names -= %w(done_ratio)
    end
    names
  end

  # Safely sets attributes
  # Should be called from controllers instead of #attributes=
  # attr_accessible is too rough because we still want things like
  # Issue.new(:project => foo) to work
  def safe_attributes=(attrs, user=User.current)
    return unless attrs.is_a?(Hash)

    attrs = attrs.deep_dup

    # Project and Tracker must be set before since new_statuses_allowed_to depends on it.
    if (p = attrs.delete('project_id')) && safe_attribute?('project_id')
      if allowed_target_projects(user).where(:id => p.to_i).exists?
        self.project_id = p
      end

      if project_id_changed? && attrs['category_id'].to_s == category_id_was.to_s
        # Discard submitted category on previous project
        attrs.delete('category_id')
      end
    end

    if (t = attrs.delete('tracker_id')) && safe_attribute?('tracker_id')
      if allowed_target_trackers(user).where(:id => t.to_i).exists?
        self.tracker_id = t
      end
    end
    if project
      # Set a default tracker to accept custom field values
      # even if tracker is not specified
      self.tracker ||= allowed_target_trackers(user).first
    end

    statuses_allowed = new_statuses_allowed_to(user)
    if (s = attrs.delete('status_id')) && safe_attribute?('status_id')
      if statuses_allowed.collect(&:id).include?(s.to_i)
        self.status_id = s
      end
    end
    if new_record? && !statuses_allowed.include?(status)
      self.status = statuses_allowed.first || default_status
    end
    if (u = attrs.delete('assigned_to_id')) && safe_attribute?('assigned_to_id')
      if u.blank?
        self.assigned_to_id = nil
      else
        u = u.to_i
        if assignable_users.any? { |assignable_user| assignable_user.id == u }
          self.assigned_to_id = u
        end
      end
    end


    attrs = delete_unsafe_attributes(attrs, user)
    return if attrs.empty?

    if attrs['parent_issue_id'].present?
      s = attrs['parent_issue_id'].to_s
      unless (m = s.match(%r{\A#?(\d+)\z})) && (m[1] == parent_id.to_s || Issue.visible(user).exists?(m[1]))
        @invalid_parent_issue_id = attrs.delete('parent_issue_id')
      end
    end

    if attrs['custom_field_values'].present?
      editable_custom_field_ids = editable_custom_field_values(user).map { |v| v.custom_field_id.to_s }
      attrs['custom_field_values'].select! { |k, v| editable_custom_field_ids.include?(k.to_s) }
    end

    if attrs['custom_fields'].present?
      editable_custom_field_ids = editable_custom_field_values(user).map { |v| v.custom_field_id.to_s }
      attrs['custom_fields'].select! { |c| editable_custom_field_ids.include?(c['id'].to_s) }
    end

    # mass-assignment security bypass
    assign_attributes attrs, :without_protection => true
  end

  def disabled_core_fields
    tracker ? tracker.disabled_core_fields : []
  end

  # Returns the custom_field_values that can be edited by the given user
  def editable_custom_field_values(user=nil)
    visible_custom_field_values(user).reject do |value|
      read_only_attribute_names(user).include?(value.custom_field_id.to_s)
    end
  end

  # Returns the custom fields that can be edited by the given user
  def editable_custom_fields(user=nil)
    editable_custom_field_values(user).map(&:custom_field).uniq
  end

  # Returns the names of attributes that are read-only for user or the current user
  # For users with multiple roles, the read-only fields are the intersection of
  # read-only fields of each role
  # The result is an array of strings where sustom fields are represented with their ids
  #
  # Examples:
  #   issue.read_only_attribute_names # => ['due_date', '2']
  #   issue.read_only_attribute_names(user) # => []
  def read_only_attribute_names(user=nil)
    workflow_rule_by_attribute(user).reject { |attr, rule| rule != 'readonly' }.keys
  end

  # Returns the names of required attributes for user or the current user
  # For users with multiple roles, the required fields are the intersection of
  # required fields of each role
  # The result is an array of strings where sustom fields are represented with their ids
  #
  # Examples:
  #   issue.required_attribute_names # => ['due_date', '2']
  #   issue.required_attribute_names(user) # => []
  def required_attribute_names(user=nil)
    workflow_rule_by_attribute(user).reject { |attr, rule| rule != 'required' }.keys
  end

  # Returns true if the attribute is required for user
  def required_attribute?(name, user=nil)
    required_attribute_names(user).include?(name.to_s)
  end

  # Returns a hash of the workflow rule by attribute for the given user
  #
  # Examples:
  #   issue.workflow_rule_by_attribute # => {'due_date' => 'required', 'start_date' => 'readonly'}
  def workflow_rule_by_attribute(user=nil)
    return @workflow_rule_by_attribute if @workflow_rule_by_attribute && user.nil?

    user_real = user || User.current
    roles = user_real.admin ? Role.all.to_a : user_real.roles_for_project(project)
    roles = roles.select(&:consider_workflow?)
    return {} if roles.empty?

    result = {}
    workflow_permissions = WorkflowPermission.where(:tracker_id => tracker_id, :old_status_id => status_id, :role_id => roles.map(&:id)).to_a
    if workflow_permissions.any?
      workflow_rules = workflow_permissions.inject({}) do |h, wp|
        h[wp.field_name] ||= {}
        h[wp.field_name][wp.role_id] = wp.rule
        h
      end
      fields_with_roles = {}
      IssueCustomField.where(:visible => false).joins(:roles).pluck(:id, "role_id").each do |field_id, role_id|
        fields_with_roles[field_id] ||= []
        fields_with_roles[field_id] << role_id
      end
      roles.each do |role|
        fields_with_roles.each do |field_id, role_ids|
          unless role_ids.include?(role.id)
            field_name = field_id.to_s
            workflow_rules[field_name] ||= {}
            workflow_rules[field_name][role.id] = 'readonly'
          end
        end
      end
      workflow_rules.each do |attr, rules|
        next if rules.size < roles.size
        uniq_rules = rules.values.uniq
        if uniq_rules.size == 1
          result[attr] = uniq_rules.first
        else
          result[attr] = 'required'
        end
      end
    end
    @workflow_rule_by_attribute = result if user.nil?
    result
  end

  private :workflow_rule_by_attribute

  def done_ratio
    if Issue.use_status_for_done_ratio? && status && status.default_done_ratio
      status.default_done_ratio
    else
      read_attribute(:done_ratio)
    end
  end

  def self.use_status_for_done_ratio?
    Setting.issue_done_ratio == 'issue_status'
  end

  def self.use_field_for_done_ratio?
    Setting.issue_done_ratio == 'issue_field'
  end

  def validate_issue
    if due_date && start_date && (start_date_changed? || due_date_changed?) && due_date < start_date
      errors.add :due_date, :greater_than_start_date
    end

    if start_date && start_date_changed? && soonest_start && start_date < soonest_start
      errors.add :start_date, :earlier_than_minimum_start_date, :date => format_date(soonest_start)
    end

    if fixed_version
      if !assignable_versions.include?(fixed_version)
        errors.add :fixed_version_id, :inclusion
      elsif reopening? && fixed_version.closed?
        errors.add :base, I18n.t(:error_can_not_reopen_issue_on_closed_version)
      end
    end

    # Checks that the issue can not be added/moved to a disabled tracker
    if project && (tracker_id_changed? || project_id_changed?)
      if tracker && !project.trackers.include?(tracker)
        errors.add :tracker_id, :inclusion
      end
    end

    # Checks parent issue assignment
    if @invalid_parent_issue_id.present?
      errors.add :parent_issue_id, :invalid
    elsif @parent_issue
      if !valid_parent_project?(@parent_issue)
        errors.add :parent_issue_id, :invalid
      elsif (@parent_issue != parent) && (
      self.would_reschedule?(@parent_issue) ||
          @parent_issue.self_and_ancestors.any? { |a| a.relations_from.any? { |r| r.relation_type == IssueRelation::TYPE_PRECEDES && r.issue_to.would_reschedule?(self) } }
      )
        errors.add :parent_issue_id, :invalid
      elsif !new_record?
        # moving an existing issue
        if move_possible?(@parent_issue)
          # move accepted
        else
          errors.add :parent_issue_id, :invalid
        end
      end
    end
  end

  # Validates the issue against additional workflow requirements
  def validate_required_fields
    user = new_record? ? author : current_journal.try(:user)

    required_attribute_names(user).each do |attribute|
      if attribute =~ /^\d+$/
        attribute = attribute.to_i
        v = custom_field_values.detect { |v| v.custom_field_id == attribute }
        if v && Array(v.value).detect(&:present?).nil?
          errors.add :base, v.custom_field.name + ' ' + l('activerecord.errors.messages.blank')
        end
      else
        if respond_to?(attribute) && send(attribute).blank? && !disabled_core_fields.include?(attribute)
          next if attribute == 'category_id' && project.try(:issue_categories).blank?
          next if attribute == 'fixed_version_id' && assignable_versions.blank?
          next if attribute == 'assigned_to_id' && new_record?
          errors.add attribute, :blank
        end
      end
    end
  end

  # Overrides Redmine::Acts::Customizable::InstanceMethods#validate_custom_field_values
  # so that custom values that are not editable are not validated (eg. a custom field that
  # is marked as required should not trigger a validation error if the user is not allowed
  # to edit this field).
  def validate_custom_field_values
    user = new_record? ? author : current_journal.try(:user)
    if new_record? || custom_field_values_changed?
      editable_custom_field_values(user).each(&:validate_value)
    end
  end

  def validate_repeat_issue
    return true if !new_record?
    issue_subject    = subject
    issue_project_id = project_id
    issue_author_id  = author_id
    repeated = Issue.reorder(created_on: :desc).limit(10).detect do |issue|
      issue.subject == subject && issue.project_id == issue_project_id && issue.author_id == issue_author_id
    end
    errors.add(:subject, l('activerecord.errors.messages.issue_repeated', :id => repeated.id)) if repeated.present?
  end

  # Set the done_ratio using the status if that setting is set.  This will keep the done_ratios
  # even if the user turns off the setting later
  def update_done_ratio_from_issue_status
    if Issue.use_status_for_done_ratio? && status && status.default_done_ratio
      self.done_ratio = status.default_done_ratio
    end
  end

  def update_mokuai_when_close
    if closed? || status.name == "已修复"
      return if mokuai_name.blank? || assigned_to_id.blank? || project.mokuai_ownners.blank?
      unless project.mokuai_ownners.find_by(:mokuai_id => mokuai_name).try(:ownner).to_a.include?(assigned_to_id.to_s)
        ownner = project.mokuai_ownners.find_by("ownner like '%- \'?\'\n%'", assigned_to_id.to_s)
        if ownner.present?
          self.mokuai_reason = ownner.mokuai.reason
          self.mokuai_name   = ownner.mokuai.id
        end
      end
    end
  end

  def init_journal(user, notes = "")
    @current_journal ||= Journal.new(:journalized => self, :user => user, :notes => notes)
  end

  # Returns the current journal or nil if it's not initialized
  def current_journal
    @current_journal
  end

  # Returns the names of attributes that are journalized when updating the issue
  def journalized_attribute_names
    names = Issue.column_names - %w(id root_id lft rgt lock_version created_on updated_on closed_on)
    if tracker
      names -= tracker.disabled_core_fields
    end
    names
  end

  # Returns the id of the last journal or nil
  def last_journal_id
    if new_record?
      nil
    else
      journals.maximum(:id)
    end
  end

  # Returns a scope for journals that have an id greater than journal_id
  def journals_after(journal_id)
    scope = journals.reorder("#{Journal.table_name}.id ASC")
    if journal_id.present?
      scope = scope.where("#{Journal.table_name}.id > ?", journal_id.to_i)
    end
    scope
  end

  # Returns the initial status of the issue
  # Returns nil for a new issue
  def status_was
    if status_id_changed?
      if status_id_was.to_i > 0
        @status_was ||= IssueStatus.find_by_id(status_id_was)
      end
    else
      @status_was ||= status
    end
  end

  # Return true if the issue is closed, otherwise false
  def closed?
    status.present? && status.is_closed?
  end

  # Returns true if the issue was closed when loaded
  def was_closed?
    status_was.present? && status_was.is_closed?
  end

  # Return true if the issue is being reopened
  def reopening?
    if new_record?
      false
    else
      status_id_changed? && !closed? && was_closed?
    end
  end

  alias :reopened? :reopening?

  def is_dakai?
    status.name == "打开" || status.name == "重打开"
  end

  # Return true if the issue is being closed
  def closing?
    if new_record?
      closed?
    else
      status_id_changed? && closed? && !was_closed?
    end
  end

  # Returns true if the issue is overdue
  def overdue?
    due_date.present? && (due_date < User.current.today) && !closed?
  end

  # Is the amount of work done less than it should for the due date
  def behind_schedule?
    return false if start_date.nil? || due_date.nil?
    done_date = start_date + ((due_date - start_date + 1) * done_ratio / 100).floor
    return done_date <= User.current.today
  end

  # Does this issue have children?
  def children?
    !leaf?
  end

  # Users the issue can be assigned to
  def assignable_users
    users = project.assignable_users.to_a
    users << author if author && author.active?
    users << assigned_to if assigned_to
    users.uniq.sort
  end

  # Versions that the issue can be assigned to
  def assignable_versions
    return @assignable_versions if @assignable_versions

    versions = project.shared_versions.open.to_a
    if fixed_version
      if fixed_version_id_changed?
        # nothing to do
      elsif project_id_changed?
        if project.shared_versions.include?(fixed_version)
          versions << fixed_version
        end
      else
        versions << fixed_version
      end
    end
    @assignable_versions = versions.uniq.sort
  end

  # Returns true if this issue is blocked by another issue that is still open
  def blocked?
    !relations_to.detect { |ir| ir.relation_type == 'blocks' && !ir.issue_from.closed? }.nil?
  end

  # Returns the default status of the issue based on its tracker
  # Returns nil if tracker is nil
  def default_status
    tracker.try(:default_status)
  end

  # Returns an array of statuses that user is able to apply
  def new_statuses_allowed_to(user=User.current, include_default=false)
    if new_record? && @copied_from
      [default_status, @copied_from.status].compact.uniq.sort
    else
      initial_status = nil
      if new_record?
        # nop
      elsif tracker_id_changed?
        if Tracker.where(:id => tracker_id_was, :default_status_id => status_id_was).any?
          initial_status = default_status
        elsif tracker.issue_status_ids.include?(status_id_was)
          initial_status = IssueStatus.find_by_id(status_id_was)
        else
          initial_status = default_status
        end
      else
        initial_status = status_was
      end

      initial_assigned_to_id = assigned_to_id_changed? ? assigned_to_id_was : assigned_to_id
      assignee_transitions_allowed = initial_assigned_to_id.present? &&
          (user.id == initial_assigned_to_id || user.group_ids.include?(initial_assigned_to_id))

      statuses = []
      statuses += IssueStatus.new_statuses_allowed(
          initial_status,
          user.admin ? Role.all.to_a : user.roles_for_project(project),
          tracker,
          author == user,
          assignee_transitions_allowed
      )
      statuses << initial_status unless statuses.empty?
      statuses << default_status if include_default || (new_record? && statuses.empty?)
      statuses = statuses.compact.uniq.sort
      if blocked?
        statuses.reject!(&:is_closed?)
      end
      statuses
    end
  end

  # Returns the previous assignee (user or group) if changed
  def assigned_to_was
    # assigned_to_id_was is reset before after_save callbacks
    user_id = @previous_assigned_to_id || assigned_to_id_was
    if user_id && user_id != assigned_to_id
      @assigned_to_was ||= Principal.find_by_id(user_id)
    end
  end

  # Returns the original tracker
  def tracker_was
    Tracker.find_by_id(tracker_id_was)
  end

  # Returns the users that should be notified
  def notified_users
    notified = []
    # Author and assignee are always notified unless they have been
    # locked or don't want to be notified
    notified << author if author
    if assigned_to
      notified += (assigned_to.is_a?(Group) ? assigned_to.users : [assigned_to])
    end
    if assigned_to_was
      notified += (assigned_to_was.is_a?(Group) ? assigned_to_was.users : [assigned_to_was])
    end
    notified = notified.select { |u| u.active? && u.notify_about?(self) }

    notified += project.notified_users
    notified.uniq!
    # Remove users that can not view the issue
    notified.reject! { |user| !visible?(user) }
    notified
  end

  # Returns the email addresses that should be notified
  def recipients
    notified_users.collect(&:mail)
  end

  def each_notification(users, &block)
    if users.any?
      if custom_field_values.detect { |value| !value.custom_field.visible? }
        users_by_custom_field_visibility = users.group_by do |user|
          visible_custom_field_values(user).map(&:custom_field_id).sort
        end
        users_by_custom_field_visibility.values.each do |users|
          yield(users)
        end
      else
        yield(users)
      end
    end
  end

  def notify?
    @notify != false
  end

  def notify=(arg)
    @notify = arg
  end

  # Returns the number of hours spent on this issue
  def spent_hours
    @spent_hours ||= time_entries.sum(:hours) || 0
  end

  # Returns the total number of hours spent on this issue and its descendants
  def total_spent_hours
    @total_spent_hours ||= if leaf?
                             spent_hours
                           else
                             self_and_descendants.joins(:time_entries).sum("#{TimeEntry.table_name}.hours").to_f || 0.0
                           end
  end

  def total_estimated_hours
    if leaf?
      estimated_hours
    else
      @total_estimated_hours ||= self_and_descendants.sum(:estimated_hours)
    end
  end

  def relations
    @relations ||= IssueRelation::Relations.new(self, (relations_from + relations_to).sort)
  end

  # Preloads relations for a collection of issues
  def self.load_relations(issues)
    if issues.any?
      relations = IssueRelation.where("issue_from_id IN (:ids) OR issue_to_id IN (:ids)", :ids => issues.map(&:id)).all
      issues.each do |issue|
        issue.instance_variable_set "@relations", relations.select { |r| r.issue_from_id == issue.id || r.issue_to_id == issue.id }
      end
    end
  end

  # Preloads visible spent time for a collection of issues
  def self.load_visible_spent_hours(issues, user=User.current)
    if issues.any?
      hours_by_issue_id = TimeEntry.visible(user).where(:issue_id => issues.map(&:id)).group(:issue_id).sum(:hours)
      issues.each do |issue|
        issue.instance_variable_set "@spent_hours", (hours_by_issue_id[issue.id] || 0)
      end
    end
  end

  # Preloads visible total spent time for a collection of issues
  def self.load_visible_total_spent_hours(issues, user=User.current)
    if issues.any?
      hours_by_issue_id = TimeEntry.visible(user).joins(:issue).
          joins("JOIN #{Issue.table_name} parent ON parent.root_id = #{Issue.table_name}.root_id" +
                    " AND parent.lft <= #{Issue.table_name}.lft AND parent.rgt >= #{Issue.table_name}.rgt").
          where("parent.id IN (?)", issues.map(&:id)).group("parent.id").sum(:hours)
      issues.each do |issue|
        issue.instance_variable_set "@total_spent_hours", (hours_by_issue_id[issue.id] || 0)
      end
    end
  end

  # Preloads visible relations for a collection of issues
  def self.load_visible_relations(issues, user=User.current)
    if issues.any?
      issue_ids = issues.map(&:id)
      # Relations with issue_from in given issues and visible issue_to
      relations_from = IssueRelation.joins(:issue_to => :project).
          where(visible_condition(user)).where(:issue_from_id => issue_ids).to_a
      # Relations with issue_to in given issues and visible issue_from
      relations_to = IssueRelation.joins(:issue_from => :project).
          where(visible_condition(user)).
          where(:issue_to_id => issue_ids).to_a
      issues.each do |issue|
        relations =
            relations_from.select { |relation| relation.issue_from_id == issue.id } +
                relations_to.select { |relation| relation.issue_to_id == issue.id }

        issue.instance_variable_set "@relations", IssueRelation::Relations.new(issue, relations.sort)
      end
    end
  end

  # Finds an issue relation given its id.
  def find_relation(relation_id)
    IssueRelation.where("issue_to_id = ? OR issue_from_id = ?", id, id).find(relation_id)
  end

  # Returns true if this issue blocks the other issue, otherwise returns false
  def blocks?(other)
    all = [self]
    last = [self]
    while last.any?
      current = last.map { |i| i.relations_from.where(:relation_type => IssueRelation::TYPE_BLOCKS).map(&:issue_to) }.flatten.uniq
      current -= last
      current -= all
      return true if current.include?(other)
      last = current
      all += last
    end
    false
  end

  # Returns true if the other issue might be rescheduled if the start/due dates of this issue change
  def would_reschedule?(other)
    all = [self]
    last = [self]
    while last.any?
      current = last.map { |i|
        i.relations_from.where(:relation_type => IssueRelation::TYPE_PRECEDES).map(&:issue_to) +
            i.leaves.to_a +
            i.ancestors.map { |a| a.relations_from.where(:relation_type => IssueRelation::TYPE_PRECEDES).map(&:issue_to) }
      }.flatten.uniq
      current -= last
      current -= all
      return true if current.include?(other)
      last = current
      all += last
    end
    false
  end

  # Returns an array of issues that duplicate this one
  def duplicates
    relations_to.select { |r| r.relation_type == IssueRelation::TYPE_DUPLICATES }.collect { |r| r.issue_from }
  end

  # Returns an array of issues that copied form this one
  def copies
    relations_from.select { |r| r.relation_type == IssueRelation::TYPE_COPIED_TO }.collect { |r| r.issue_to }
  end

  # Returns the due date or the target due date if any
  # Used on gantt chart
  def due_before
    due_date || (fixed_version ? fixed_version.effective_date : nil)
  end

  # Returns the time scheduled for this issue.
  #
  # Example:
  #   Start Date: 2/26/09, End Date: 3/04/09
  #   duration => 6
  def duration
    (start_date && due_date) ? due_date - start_date : 0
  end

  # Returns the duration in working days
  def working_duration
    (start_date && due_date) ? working_days(start_date, due_date) : 0
  end

  def soonest_start(reload=false)
    if @soonest_start.nil? || reload
      dates = relations_to(reload).collect { |relation| relation.successor_soonest_start }
      p = @parent_issue || parent
      if p && Setting.parent_issue_dates == 'derived'
        dates << p.soonest_start
      end
      @soonest_start = dates.compact.max
    end
    @soonest_start
  end

  # Sets start_date on the given date or the next working day
  # and changes due_date to keep the same working duration.
  def reschedule_on(date)
    wd = working_duration
    date = next_working_date(date)
    self.start_date = date
    self.due_date = add_working_days(date, wd)
  end

  # Reschedules the issue on the given date or the next working day and saves the record.
  # If the issue is a parent task, this is done by rescheduling its subtasks.
  def reschedule_on!(date)
    return if date.nil?
    if leaf? || !dates_derived?
      if start_date.nil? || start_date != date
        if start_date && start_date > date
          # Issue can not be moved earlier than its soonest start date
          date = [soonest_start(true), date].compact.max
        end
        reschedule_on(date)
        begin
          save
        rescue ActiveRecord::StaleObjectError
          reload
          reschedule_on(date)
          save
        end
      end
    else
      leaves.each do |leaf|
        if leaf.start_date
          # Only move subtask if it starts at the same date as the parent
          # or if it starts before the given date
          if start_date == leaf.start_date || date > leaf.start_date
            leaf.reschedule_on!(date)
          end
        else
          leaf.reschedule_on!(date)
        end
      end
    end
  end

  def dates_derived?
    !leaf? && Setting.parent_issue_dates == 'derived'
  end

  def priority_derived?
    !leaf? && Setting.parent_issue_priority == 'derived'
  end

  def done_ratio_derived?
    !leaf? && Setting.parent_issue_done_ratio == 'derived'
  end

  def <=>(issue)
    if issue.nil?
      -1
    elsif root_id != issue.root_id
      (root_id || 0) <=> (issue.root_id || 0)
    else
      (lft || 0) <=> (issue.lft || 0)
    end
  end

  def to_s
    "#{tracker} ##{id}: #{subject}"
  end

  # Returns a string of css classes that apply to the issue
  def css_classes(user=User.current)
    s = "issue tracker-#{tracker_id} status-#{status_id} #{priority.try(:css_classes)}"
    s << ' closed' if closed?
    s << ' overdue' if overdue?
    s << ' child' if child?
    s << ' parent' unless leaf?
    s << ' private' if is_private?
    if user.logged?
      s << ' created-by-me' if author_id == user.id
      s << ' assigned-to-me' if assigned_to_id == user.id
      s << ' assigned-to-my-group' if user.groups.any? { |g| g.id == assigned_to_id }
    end
    s
  end

  # Unassigns issues from +version+ if it's no longer shared with issue's project
  def self.update_versions_from_sharing_change(version)
    # Update issues assigned to the version
    update_versions(["#{Issue.table_name}.fixed_version_id = ?", version.id])
  end

  # Unassigns issues from versions that are no longer shared
  # after +project+ was moved
  def self.update_versions_from_hierarchy_change(project)
    moved_project_ids = project.self_and_descendants.reload.collect(&:id)
    # Update issues of the moved projects and issues assigned to a version of a moved project
    Issue.update_versions(
        ["#{Version.table_name}.project_id IN (?) OR #{Issue.table_name}.project_id IN (?)",
         moved_project_ids, moved_project_ids]
    )
  end

  def parent_issue_id=(arg)
    s = arg.to_s.strip.presence
    if s && (m = s.match(%r{\A#?(\d+)\z})) && (@parent_issue = Issue.find_by_id(m[1]))
      @invalid_parent_issue_id = nil
    elsif s.blank?
      @parent_issue = nil
      @invalid_parent_issue_id = nil
    else
      @parent_issue = nil
      @invalid_parent_issue_id = arg
    end
  end

  def parent_issue_id
    if @invalid_parent_issue_id
      @invalid_parent_issue_id
    elsif instance_variable_defined? :@parent_issue
      @parent_issue.nil? ? nil : @parent_issue.id
    else
      parent_id
    end
  end

  def set_parent_id
    self.parent_id = parent_issue_id
  end

  # Returns true if issue's project is a valid
  # parent issue project
  def valid_parent_project?(issue=parent)
    return true if issue.nil? || issue.project_id == project_id

    case Setting.cross_project_subtasks
      when 'system'
        true
      when 'tree'
        issue.project.root == project.root
      when 'hierarchy'
        issue.project.is_or_is_ancestor_of?(project) || issue.project.is_descendant_of?(project)
      when 'descendants'
        issue.project.is_or_is_ancestor_of?(project)
      else
        false
    end
  end

  # Returns an issue scope based on project and scope
  def self.cross_project_scope(project, scope=nil)
    if project.nil?
      return Issue
    end
    case scope
      when 'all', 'system'
        Issue
      when 'tree'
        Issue.joins(:project).where("(#{Project.table_name}.lft >= :lft AND #{Project.table_name}.rgt <= :rgt)",
                                    :lft => project.root.lft, :rgt => project.root.rgt)
      when 'hierarchy'
        Issue.joins(:project).where("(#{Project.table_name}.lft >= :lft AND #{Project.table_name}.rgt <= :rgt) OR (#{Project.table_name}.lft < :lft AND #{Project.table_name}.rgt > :rgt)",
                                    :lft => project.lft, :rgt => project.rgt)
      when 'descendants'
        Issue.joins(:project).where("(#{Project.table_name}.lft >= :lft AND #{Project.table_name}.rgt <= :rgt)",
                                    :lft => project.lft, :rgt => project.rgt)
      else
        Issue.where(:project_id => project.id)
    end
  end

  def self.by_tracker(project)
    count_and_group_by(:project => project, :association => :tracker)
  end

  def self.by_version(project)
    count_and_group_by(:project => project, :association => :fixed_version)
  end

  def self.by_priority(project)
    count_and_group_by(:project => project, :association => :priority)
  end

  def self.by_category(project)
    count_and_group_by(:project => project, :association => :category)
  end

  def self.by_assigned_to(project)
    count_and_group_by(:project => project, :association => :assigned_to)
  end

  def self.by_author(project)
    count_and_group_by(:project => project, :association => :author)
  end

  def self.by_subproject(project)
    r = count_and_group_by(:project => project, :with_subprojects => true, :association => :project)
    r.reject { |r| r["project_id"] == project.id.to_s }
  end

  # Query generator for selecting groups of issue counts for a project
  # based on specific criteria
  #
  # Options
  # * project - Project to search in.
  # * with_subprojects - Includes subprojects issues if set to true.
  # * association - Symbol. Association for grouping.
  def self.count_and_group_by(options)
    assoc = reflect_on_association(options[:association])
    select_field = assoc.foreign_key

    Issue.
        visible(User.current, :project => options[:project], :with_subprojects => options[:with_subprojects]).
        joins(:status, assoc.name).
        group(:status_id, :is_closed, select_field).
        count.
        map do |columns, total|
      status_id, is_closed, field_value = columns
      is_closed = ['t', 'true', '1'].include?(is_closed.to_s)
      {
          "status_id" => status_id.to_s,
          "closed" => is_closed,
          select_field => field_value.to_s,
          "total" => total.to_s
      }
    end
  end

  # Returns a scope of projects that user can assign the issue to
  def allowed_target_projects(user=User.current)
    current_project = new_record? ? nil : project
    self.class.allowed_target_projects(user, current_project)
  end

  # Returns a scope of projects that user can assign issues to
  # If current_project is given, it will be included in the scope
  def self.allowed_target_projects(user=User.current, current_project=nil)
    condition = Project.allowed_to_condition(user, :add_issues)
    if current_project
      condition = ["(#{condition}) OR #{Project.table_name}.id = ?", current_project.id]
    end
    Project.where(condition).having_trackers
  end

  # Returns a scope of trackers that user can assign the issue to
  def allowed_target_trackers(user=User.current)
    self.class.allowed_target_trackers(project, user, tracker_id_was)
  end

  # Returns a scope of trackers that user can assign project issues to
  def self.allowed_target_trackers(project, user=User.current, current_tracker=nil)
    if project
      scope = project.trackers.sorted
      unless user.admin?
        roles = user.roles_for_project(project).select { |r| r.has_permission?(:add_issues) }
        unless roles.any? { |r| r.permissions_all_trackers?(:add_issues) }
          tracker_ids = roles.map { |r| r.permissions_tracker_ids(:add_issues) }.flatten.uniq
          if current_tracker
            tracker_ids << current_tracker
          end
          scope = scope.where(:id => tracker_ids)
        end
      end
      scope
    else
      Tracker.none
    end
  end

  def ownner
    return assigned_to
  end

  def mokuai_ownner
    if project.mokuai_ownners.present? && mokuai.present?
      mokuai_ownner = project.mokuai_ownners.find_by(:mokuai_id => mokuai)
      mokuai_ownner.ownner.first if mokuai_ownner.present?
    end
  end

  def mokuai_tfde
    if project.mokuai_ownners.present? && mokuai.present?
      mokuai_ownner = project.mokuai_ownners.find_by(:mokuai_id => mokuai)
      mokuai_ownner.tfde if mokuai_ownner.present?
    end
  end

  def need_open?
    self.assigned_to == User.current &&
        ["分配", "重分配"].include?(self.status.name) &&
        self.new_statuses_allowed_to(User.current).map(&:name).include?("打开")
  end

  def auto_open!
    if self.need_open?
      self.init_journal(User.current)
      self.status_id = IssueStatus.find_by(:name => "打开")
      self.save
    end
  end

  def probability
    cv = custom_value_by_custom_field_name("概率")
    cv && cv.value
  end

  def relations_issues_editable?
    relations = self.relations.select { |r| r.other_issue(self) && r.other_issue(self).visible? }
    relations.present? && relations.map { |relation| relation.other_issue(self).editable? }.include?(true)
  end

  def is_app_project_issue?
    project.category.to_i == 4
  end

  def is_demand_tracker_issue?
    demand_id = Tracker.where("name LIKE '%需求%'").first
    demand_id.present?? tracker_id == demand_id : false
  end

  def latest_note
    if journals.present?
      note = journals.where("notes <> ''").to_a.last
      notes = note.present?? "[#{note.user.name} #{l(:field_updated_on)} #{format_time note.created_on}] #{note.notes}" : nil
    end
  end

  def status_histories
    histories = status_and_assigned_history(self)
    histories.to_s
  end

  def dept_of_assigned_to
    # query = RequestStore.store[:current_issue_query]
    # if column_names = query.try(:column_names)
    #   name = ([:assigned_to, :author] & column_names).first
    #   self.send(name).try(:dept_name)
    # end
    assigned_to.try(:dept_name)
  end

  def dept_of_author
    author.try(:dept_name)
  end

  def find_umpire
    if by_tester
      if author.parentOrgNm == '品质管理部软件评测中心'
        role_id = 44
      elsif author.orgNm == '测试项目部'
        role_id = 15
      else
        role_id = nil
      end
    else
      role_id = nil
    end

    members = project.members.joins(:member_roles).where(member_roles: {role_id: role_id}).reorder("id asc")
    umpire = members.present? ? members.first.user : nil

    return umpire
  end

  def update_umpire 
    issue = self
    umpire = issue.find_umpire
    issue.update_columns(umpire_id: umpire.id) if umpire.present?
  end

  def last_umpirage_approver
    journal_ids = journals.pluck(:id)
    detail = JournalDetail.where(journal_id: journal_ids, prop_key: 'status_id', value: 23).reorder("id desc").first
    approver = detail.present? ? detail.journal.user : assigned_to
  end

  def to_notice_apply_umpirate
    issue = self
    user = issue.last_umpirage_approver
    project = issue.project
    
    current_masters, current_master_ids = user.find_umpirage_approver
    master = current_masters || [User.where(:admin => true, status: 1).third]

    current_master_ids.each do |m|
      member = project.members.find_by(:user_id => m) || Member.new(:project => project, :user_id => m)
      member.set_editable_role_ids(([Role.umpirage.id] | member.role_ids), User.find_by(admin: true))
      member.save
    end
 
    issue.update_columns(:umpirage_approver_id => current_master_ids) if current_master_ids.present?
    
    #Send email and notification

    # ActionMailer::Base.raise_delivery_errors = true
    # begin
    #   master.each do |m|
    #     Mailer.with_synched_deliveries do
    #       Mailer.apply_umpirage_notification(m, :user => user, :issue => issue).deliver
    #     end
    #   end
    # rescue => e
    #   puts "[#{Time.now.to_s(:db)}] #{e.message}"
    # end
    # master.each do |m|
    #   Notification.apply_umpirage_notification(m, :user => user, :issue => issue)
    # end
  end

  def merge_update_closed_on_and_due_date_incase
    if (closeds = IssueStatus::CLOSE_STATUS.split(",")).include?(status_id.to_s)
      unless closed_on.present?
        detail = JournalDetail.includes(:journal)
                              .where(journals: {journalized_id: self.id}, prop_key: "status_id", value: closeds)
                              .reorder("journals.created_on desc").first
        self.update_columns(closed_on: detail.journal.created_on)  if detail.present?
      end
    elsif (repaireds = IssueStatus::REPAIRED_STATUS.split(",")).include?(status_id.to_s)
      unless due_date.present?
        detail = JournalDetail.includes(:journal)
                              .where(journals: {journalized_id: self.id}, prop_key: "status_id", value: repaireds)
                              .reorder("journals.created_on desc").first
        self.update_columns(due_date: detail.journal.created_on)  if detail.present?
      end
    else
      update_params = {}
      update_params[:due_date] = nil if due_date.present?
      update_params[:closed_on] = nil if closed_on.present?
      self.update_columns(update_params) if update_params.present?
    end
  end

  #####


  private

  def user_tracker_permission?(user, permission)
    if user.admin?
      true
    else
      roles = user.roles_for_project(project).select { |r| r.has_permission?(permission) }
      roles.any? { |r| r.permissions_all_trackers?(permission) || r.permissions_tracker_ids?(permission, tracker_id) }
    end
  end

  def after_project_change
    # Update project_id on related time entries
    TimeEntry.where({:issue_id => id}).update_all(["project_id = ?", project_id])

    # Delete issue relations
    unless Setting.cross_project_issue_relations?
      relations_from.clear
      relations_to.clear
    end

    # Move subtasks that were in the same project
    children.each do |child|
      next unless child.project_id == project_id_was
      # Change project and keep project
      child.send :project=, project, true
      unless child.save
        raise ActiveRecord::Rollback
      end
    end
  end

  # Callback for after the creation of an issue by copy
  # * adds a "copied to" relation with the copied issue
  # * copies subtasks from the copied issue
  def after_create_from_copy
    return unless copy? && !@after_create_from_copy_handled

    if (@copied_from.project_id == project_id || Setting.cross_project_issue_relations?) && @copy_options[:link] != false
      if @current_journal
        @copied_from.init_journal(@current_journal.user)
      end
      relation = IssueRelation.new(:issue_from => @copied_from, :issue_to => self, :relation_type => IssueRelation::TYPE_COPIED_TO)
      unless relation.save
        logger.error "Could not create relation while copying ##{@copied_from.id} to ##{id} due to validation errors: #{relation.errors.full_messages.join(', ')}" if logger
      end
    end

    unless @copied_from.leaf? || @copy_options[:subtasks] == false
      copy_options = (@copy_options || {}).merge(:subtasks => false)
      copied_issue_ids = {@copied_from.id => self.id}
      @copied_from.reload.descendants.reorder("#{Issue.table_name}.lft").each do |child|
        # Do not copy self when copying an issue as a descendant of the copied issue
        next if child == self
        # Do not copy subtasks of issues that were not copied
        next unless copied_issue_ids[child.parent_id]
        # Do not copy subtasks that are not visible to avoid potential disclosure of private data
        unless child.visible?
          logger.error "Subtask ##{child.id} was not copied during ##{@copied_from.id} copy because it is not visible to the current user" if logger
          next
        end
        copy = Issue.new.copy_from(child, copy_options)
        if @current_journal
          copy.init_journal(@current_journal.user)
        end
        copy.author = author
        copy.project = project
        copy.parent_issue_id = copied_issue_ids[child.parent_id]
        unless copy.save
          logger.error "Could not copy subtask ##{child.id} while copying ##{@copied_from.id} to ##{id} due to validation errors: #{copy.errors.full_messages.join(', ')}" if logger
          next
        end
        copied_issue_ids[child.id] = copy.id
      end
    end
    @after_create_from_copy_handled = true
  end

  def update_nested_set_attributes
    if parent_id_changed?
      update_nested_set_attributes_on_parent_change
    end
    remove_instance_variable(:@parent_issue) if instance_variable_defined?(:@parent_issue)
  end

  # Updates the nested set for when an existing issue is moved
  def update_nested_set_attributes_on_parent_change
    former_parent_id = parent_id_was
    # delete invalid relations of all descendants
    self_and_descendants.each do |issue|
      issue.relations.each do |relation|
        relation.destroy unless relation.valid?
      end
    end
    # update former parent
    recalculate_attributes_for(former_parent_id) if former_parent_id
  end

  def update_parent_attributes
    if parent_id
      recalculate_attributes_for(parent_id)
      association(:parent).reset
    end
  end

  def recalculate_attributes_for(issue_id)
    if issue_id && p = Issue.find_by_id(issue_id)
      if p.priority_derived?
        # priority = highest priority of open children
        if priority_position = p.children.open.joins(:priority).maximum("#{IssuePriority.table_name}.position")
          p.priority = IssuePriority.find_by_position(priority_position)
        else
          p.priority = IssuePriority.default
        end
      end

      if p.dates_derived?
        # start/due dates = lowest/highest dates of children
        p.start_date = p.children.minimum(:start_date)
        p.due_date = p.children.maximum(:due_date)
        if p.start_date && p.due_date && p.due_date < p.start_date
          p.start_date, p.due_date = p.due_date, p.start_date
        end
      end

      if p.done_ratio_derived?
        # done ratio = weighted average ratio of leaves
        unless Issue.use_status_for_done_ratio? && p.status && p.status.default_done_ratio
          child_count = p.children.count
          if child_count > 0
            average = p.children.where("estimated_hours > 0").average(:estimated_hours).to_f
            if average == 0
              average = 1
            end
            done = p.children.joins(:status).
                sum("COALESCE(CASE WHEN estimated_hours > 0 THEN estimated_hours ELSE NULL END, #{average}) " +
                        "* (CASE WHEN is_closed = #{self.class.connection.quoted_true} THEN 100 ELSE COALESCE(done_ratio, 0) END)").to_f
            progress = done / (average * child_count)
            p.done_ratio = progress.round
          end
        end
      end

      # ancestors will be recursively updated
      p.save(:validate => false)
    end
  end

  # Update issues so their versions are not pointing to a
  # fixed_version that is not shared with the issue's project
  def self.update_versions(conditions=nil)
    # Only need to update issues with a fixed_version from
    # a different project and that is not systemwide shared
    Issue.joins(:project, :fixed_version).
        where("#{Issue.table_name}.fixed_version_id IS NOT NULL" +
                  " AND #{Issue.table_name}.project_id <> #{Version.table_name}.project_id" +
                  " AND #{Version.table_name}.sharing <> 'system'").
        where(conditions).each do |issue|
      next if issue.project.nil? || issue.fixed_version.nil?
      unless issue.project.shared_versions.include?(issue.fixed_version)
        issue.init_journal(User.current)
        issue.fixed_version = nil
        issue.save
      end
    end
  end

  # Callback on file attachment
  def attachment_added(attachment)
    if current_journal && !attachment.new_record?
      current_journal.journalize_attachment(attachment, :added)
    end
  end

  # Callback on attachment deletion
  def attachment_removed(attachment)
    if current_journal && !attachment.new_record?
      current_journal.journalize_attachment(attachment, :removed)
      current_journal.save
    end
  end

  # Called after a relation is added
  def relation_added(relation)
    if current_journal
      current_journal.journalize_relation(relation, :added)
      current_journal.save
    end
  end

  # Called after a relation is removed
  def relation_removed(relation)
    if current_journal
      current_journal.journalize_relation(relation, :removed)
      current_journal.save
    end
  end

  # Default assignment based on category
  def default_assign
    if assigned_to.nil?
      if category && category.assigned_to
        self.assigned_to = category.assigned_to
      else
        self.assigned_to_id = mokuai_ownner
        self.tfde_id        = mokuai_tfde
      end
    end
    self.assigned_to = nil unless self.assigned_to.try(:active?)
    self.tfde_id     = nil unless self.tfde.try(:active?)
    self.assigned_to ||= author
  end

  # Updates start/due dates of following issues
  def reschedule_following_issues
    if start_date_changed? || due_date_changed?
      relations_from.each do |relation|
        relation.set_issue_to_dates
      end
    end
  end

  # Closes duplicates if the issue is being closed
  def close_duplicates
    if closing?
      duplicates.each do |duplicate|
        # Reload is needed in case the duplicate was updated by a previous duplicate
        duplicate.reload
        # Don't re-close it if it's already closed
        next if duplicate.closed?
        # Same user and notes
        if @current_journal
          duplicate.init_journal(@current_journal.user, @current_journal.notes)
          duplicate.private_notes = @current_journal.private_notes
        end
        duplicate.update_attribute :status, self.status
      end
    end
  end

  # Change copies status if the issue status is being changed
  def change_copies_status
    if status_was.present? && status_id != status_was.id && IssueStatus::COPIES_ISSUE_CHANGE_STATUS.include?(status.try(:name))
      copies.each do |copy|
        copy.reload
        next if IssueStatus::COPIES_ISSUE_CLOSED_STATUS.include?(copy.status.try(:name))
        if @current_journal
          copy.init_journal(@current_journal.user, @current_journal.notes)
          copy.private_notes = @current_journal.private_notes
        end
        copy.update_attribute :status, self.status
      end
    end
  end

  # Make sure updated_on is updated when adding a note and set updated_on now
  # so we can set closed_on with the same value on closing
  def force_updated_on_change
    if @current_journal || changed?
      self.updated_on = current_time_from_proper_timezone
      if new_record?
        self.created_on = updated_on
      end
    end
  end

  # Callback for setting closed_on when the issue is closed.
  # The closed_on attribute stores the time of the last closing
  # and is preserved when the issue is reopened.
  def update_closed_on
    if closing?
      self.closed_on = updated_on
      self.estimated_hours = (updated_on.to_date - start_date).to_i if self.start_date && status_was.name != "已修复"
    else
      self.closed_on = nil
    end
  end

  def update_start_or_due_date
    return unless self.tracker_id == 1
    if status_was.present? && status_id != status_was.id
      case status.name
        when "分配", "打开"
         self.start_date = Date.today unless self.start_date
        when "已修复"
         self.due_date = Date.today
         self.estimated_hours = (updated_on.to_date - start_date).to_i if self.start_date
      end
    end
  end

  # Saves the changes in a Journal
  # Called after_save
  def create_journal
    if current_journal
      current_journal.save
    end
  end

  def send_notification
    if notify? && Setting.notified_events.include?('issue_added')
      Mailer.deliver_issue_add(self)
    end
  end

  def refresh_issues_redis_cache
    begin
      redis = Redis.new
      redis.srem("amigo_issues", redis.sort("amigo_issues", :limit => [0,1]).first) # Delete oldest id from Redis
      redis.sadd("amigo_issues", id) # Add current id to Redis
      redis.mapped_hmset("amigo_issue_latest", {"id" => id, "expired_on" => Time.now + 10.minutes}) # set latest issue
    rescue => e
      logger.info("\nRedisError #{e}: (#{File.expand_path(__FILE__)})\n")
    end
  end

  # Stores the previous assignee so we can still have access
  # to it during after_save callbacks (assigned_to_id_was is reset)
  def set_assigned_to_was
    @previous_assigned_to_id = assigned_to_id_was
  end

  # Check and modify subject wildcards: %project% %id%
  def check_subject_wildcards
    replacement = {"%project%" => project.identifier.upcase, "%id%" => id.to_s}
    return unless self.description =~ %r(#{replacement.keys.join("|")})
    replacement.each do |re|
      self.description = self.description.gsub(/((https|http|ftp)?:\/\/)[^\s]+/) { |url| url.to_s.gsub re.first, re.last }
    end
    update_column :description, self.description
  end

  def to_do_when_status_changed
    if status_was.present? && status_id != status_was.id
      if status.name == "裁决"
        update_umpire
      end

      if status.name == "申请裁决"
        to_notice_apply_umpirate
        #ApplyUmpirageJob.perform_later([self.id, User.current.id])
      end

      if status.name == "重打开"
        self.app_version_id = nil
        self.integration_version_id = nil
      end
    end
  end

  # Clears the previous assignee at the end of after_save callbacks
  def clear_assigned_to_was
    @assigned_to_was = nil
    @previous_assigned_to_id = nil
  end

  def clear_disabled_fields
    if tracker
      tracker.disabled_core_fields.each do |attribute|
        send "#{attribute}=", nil
      end
      self.done_ratio ||= 0
      self.priority_id ||= 0
    end
  end

  def custom_value_by_custom_field_name(cf_name)
    cf_id = CustomField.find_by_name(cf_name)
    CustomValue.find_by_customized_id_and_custom_field_id_and_customized_type(self.id, cf_id, "Issue")
  end

  def self.update_umpirage_approver
    @issues = self.where(status_id: IssueStatus::APPY_UMPIRAGE_STATUS)

    @issues.each do |issue|
      last_umpirage_approver = issue.last_umpirage_approver
      masters, master_ids = last_umpirage_approver.find_umpirage_approver
      issue.update_columns(umpirage_approver_id: master_ids) if master_ids.present?
    end
  end
end
