class IssueToSpecialTestResult < ActiveRecord::Base
  has_one :task, :as => :container
  has_many :alter_records, :as => :alter_for, :dependent => :destroy, :inverse_of => :alter_for
  belongs_to :special_test, class_name: "IssueToSpecialTest", foreign_key: "special_test_id"
  belongs_to :designer, class_name: "User", foreign_key: "designer_id"
  belongs_to :assigner, class_name: "User", foreign_key: "assigned_to_id"

  ISSUE_TO_SPECIAL_TEST_RESULT_RESULT = { :recurrent => 1, :norecurrent => 2}

  validates :designer_id, :assigned_to_id, presence: true, if: :new?
  validates :steps, presence: true, if: :design?
  validates :sample_num, :catch_log_way, :result, :start_date, :due_date, presence: true, if: :assign?

  after_save :create_alter

  acts_as_attachable :view_permission => :view_files,
                     :edit_permission => :manage_files,
                     :delete_permission => :manage_files

  def new?
    task.blank?
  end

  def design?
    task.present? && task.status == "assigned" && !changed.include?("assigned_to_id")
  end

  def assign?
    task.present? && task.status == "designed" && !changed.include?("assigned_to_id")
  end

  def project
    special_test.project
  end

  def owners
    ids = [designer_id, assigned_to_id, task.author_id].uniq
  end

  #change record
  def init_alter(notes = "")
    @current_alter ||= AlterRecord.new(:alter_for => self, :user => User.current)
  end

  # Returns the current journal or nil if it's not initialized
  def current_alter
    @current_alter
  end

  def create_alter
    if current_alter
      current_alter.save
    end
  end

  def altered_attribute_names
    names = IssueToSpecialTestResult.column_names - %w(id special_test_id designer_id created_at updated_at)
  end
end