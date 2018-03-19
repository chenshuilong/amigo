class VersionIssue < ActiveRecord::Base

  belongs_to :version
  belongs_to :issue

  ISSUE_TYPE_AMIGO      = 1
  ISSUE_TYPE_CLEARQUEST = 2
  ISSUE_TYPE_BEIYAN     = 3

  VERSION_ISSUE_ISSUE_TYPE = {:amigo => 1, :clearquest => 2, :beiyan => 3}


  validates :issue_type, :issue_id, presence: true
  validates :issue_id, :uniqueness => { scope: [:version_id, :issue_type], :message => :already_exists }

  def issue
    if issue_type == VERSION_ISSUE_ISSUE_TYPE[:amigo] && (issue = Issue.find_by(:id => issue_id))
      @issue ||= issue
    else
      @issue ||= RelatedIssue.new(self)
    end
  end


  class RelatedIssue
    attr_accessor :id, :status, :subject, :assigned_to
    # include Redmine::I18n

    def initialize(version_issue, options={})
      self.status = version_issue.status
      self.subject = version_issue.subject
      self.assigned_to = version_issue.assigned_to
      if version_issue.issue_type == VersionIssue::VERSION_ISSUE_ISSUE_TYPE[:clearquest]
        self.id = "CR%08d"%[version_issue.issue_id]
      else
        self.id = version_issue.issue_id
      end
    end
  end

end
