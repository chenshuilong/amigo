class IssueToApproveMerge < ActiveRecord::Base
  belongs_to :issue

  acts_as_task :view_permission => :view_issue_to_merges,
               :edit_permission => :edit_issue_to_merges,
               :delete_permission => :edit_issue_to_merges

  ISSUE_TYPE = ['IssueToApprove', 'IssueToMerge']
  JENKINS_JOB_NAME = ["auto_cherry_pick_for_amige"]

  validates_inclusion_of :issue_type, :in => ISSUE_TYPE, :allow_blank => false, :message => "数据类型出现异常。"
  scope :approves, -> {where(:issue_type => 'IssueToApprove')}
  scope :merges, -> {where(:issue_type => 'IssueToMerge')}

  scope :assigned_to_me, lambda { |assigned_to_id, sql, order|
    find_by_sql("select * from v_approve_merge_tasks where task_assigned_to_id = #{assigned_to_id} and #{sql.blank? ? '1=1' : sql}")
  }

end