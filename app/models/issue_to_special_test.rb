class IssueToSpecialTest < ActiveRecord::Base
  include AASM
  
  has_many :results, class_name:"IssueToSpecialTestResult", foreign_key: "special_test_id"
  has_one :task, :as => :container
  belongs_to :project
  belongs_to :author, class_name:"User", foreign_key: "author_id"

  ISSUE_TO_SPECIAL_TEST_STATUS = { :submitted => 1, :agreed => 2, :refused => 3}
  ISSUE_TO_SPECIAL_TEST_CATEGORY = { "r&d" => 1, "special" => 2, "test" => 3}
  ISSUE_TO_SPECIAL_TEST_PRIORITY = { :high => 1, :normal => 2, :low => 3}

  validates :category, :subject, :related_issues, :test_times, :machine_num,
            :test_method, :attentions, :test_version, :precondition, presence: true
  validates :priority, :approval_result, presence: true, if: :judge?

  enum status: ISSUE_TO_SPECIAL_TEST_STATUS

  # Define Workflow
  aasm :column => :status, :enum => true, :logger => Rails.logger do
    state :submitted, :initial => true
    state :agreed, :refused
  end

  def judge?
    #测试负责人可以评审
    !new_record? && project.users_of_role(15).map(&:id).include?(User.current.id)
  end
end