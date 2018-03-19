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

class IssueStatus < ActiveRecord::Base
  SOLVED_STATUS = "11,12,13" # self.where("name in ('已修复','已验证','关闭')").pluck(:id).join(',')
  UNSOLVED_STATUS = "7,8,9" # self.where("name in ('分配','打开','重分配')").pluck(:id).join(',')
  LEAVE_STATUS = "7,8,9,10" # self.where("name in ('分配','打开','重分配','重打开')").pluck(:id).join(',')
  REOPEN_STATUS = "10" # self.where(:name => "重打开").pluck(:id).join(',')
  OPEN_STATUS = "9" # self.where(:name => "打开").pluck(:id).join(',')
  REASSIGNED_STATUS = "8" # self.where(:name => "重分配").pluck(:id).join(',')
  ASSIGNED_STATUS = "7" # self.where(:name => "分配").pluck(:id).join(',')
  REPAIRED_STATUS = "11" # self.where(:name => "已修复").pluck(:id).join(',')
  VERIFICATED_STATUS = "12" # self.where(:name => "已验证").pluck(:id).join(',')
  COMMIT_STATUS = "21" # self.where(:name => "提交").pluck(:id).join(',')
  CLOSE_STATUS = "13" # self.where(:name => "关闭").pluck(:id).join(',')
  ANALYSIS_STATUS = "22" # self.where(:name => "三方分析").pluck(:id).join(',')
  APPY_UMPIRAGE_STATUS  = "23" # self.where(:name => "申请裁决").pluck(:id).join(',')
  DOUBT_STATUS = "24" # self.where(:name => "无法理解").pluck(:id).join(',')
  REPEAT_STATUS = "15" # self.where(:name => "重复").pluck(:id).join(',')
  REFUSE_STATUS = "14" # self.where(:name => "拒绝").pluck(:id).join(',')
  CAIJUE_STATUS = "20" # self.where(:name => "裁决").pluck(:id).join(',')
  
  COPIES_ISSUE_CHANGE_STATUS = %w(拒绝 裁决 已修复)
  COPIES_ISSUE_CLOSED_STATUS = %w(关闭 协商关闭)
  SUBMIT_STATUS = '提交'


  before_destroy :check_integrity
  has_many :workflows, :class_name => 'WorkflowTransition', :foreign_key => "old_status_id"
  has_many :workflow_transitions_as_new_status, :class_name => 'WorkflowTransition', :foreign_key => "new_status_id"
  acts_as_positioned

  after_update :handle_is_closed_change
  before_destroy :delete_workflow_rules

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_length_of :name, :maximum => 30
  validates_inclusion_of :default_done_ratio, :in => 0..100, :allow_nil => true
  attr_protected :id

  scope :sorted, lambda { order(:position) }
  scope :named, lambda {|arg| where("LOWER(#{table_name}.name) = LOWER(?)", arg.to_s.strip)}

  # Update all the +Issues+ setting their done_ratio to the value of their +IssueStatus+
  def self.update_issue_done_ratios
    if Issue.use_status_for_done_ratio?
      IssueStatus.where("default_done_ratio >= 0").each do |status|
        Issue.where({:status_id => status.id}).update_all({:done_ratio => status.default_done_ratio})
      end
    end

    return Issue.use_status_for_done_ratio?
  end

  # Returns an array of all statuses the given role can switch to
  def new_statuses_allowed_to(roles, tracker, author=false, assignee=false)
    self.class.new_statuses_allowed(self, roles, tracker, author, assignee)
  end
  alias :find_new_statuses_allowed_to :new_statuses_allowed_to

  def self.new_statuses_allowed(status, roles, tracker, author=false, assignee=false)
    if roles.present? && tracker
      status_id = status.try(:id) || 0

      scope = IssueStatus.
        joins(:workflow_transitions_as_new_status).
        where(:workflows => {:old_status_id => status_id, :role_id => roles.map(&:id), :tracker_id => tracker.id})

      unless author && assignee
        if author || assignee
          scope = scope.where("author = ? OR assignee = ?", author, assignee)
        else
          scope = scope.where("author = ? AND assignee = ?", false, false)
        end
      end

      scope.uniq.to_a.sort
    else
      []
    end
  end

  def <=>(status)
    position <=> status.position
  end

  def to_s; name end

  private

  # Updates issues closed_on attribute when an existing status is set as closed.
  def handle_is_closed_change
    if is_closed_changed? && is_closed == true
      # First we update issues that have a journal for when the current status was set,
      # a subselect is used to update all issues with a single query
      subselect = "SELECT MAX(j.created_on) FROM #{Journal.table_name} j" +
        " JOIN #{JournalDetail.table_name} d ON d.journal_id = j.id" +
        " WHERE j.journalized_type = 'Issue' AND j.journalized_id = #{Issue.table_name}.id" +
        " AND d.property = 'attr' AND d.prop_key = 'status_id' AND d.value = :status_id"
      Issue.where(:status_id => id, :closed_on => nil).
        update_all(["closed_on = (#{subselect})", {:status_id => id.to_s}])

      # Then we update issues that don't have a journal which means the
      # current status was set on creation
      Issue.where(:status_id => id, :closed_on => nil).update_all("closed_on = created_on")
    end
  end

  def check_integrity
    if Issue.where(:status_id => id).any?
      raise "This status is used by some issues"
    elsif Tracker.where(:default_status_id => id).any?
      raise "This status is used as the default status by some trackers"
    end
  end

  # Deletes associated workflows
  def delete_workflow_rules
    WorkflowRule.delete_all(["old_status_id = :id OR new_status_id = :id", {:id => id}])
  end
end
