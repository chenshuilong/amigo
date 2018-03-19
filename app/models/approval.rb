class Approval < ActiveRecord::Base

  belongs_to :user
  self.inheritance_column = nil

  scope :umpirages, -> {where :type => "UmpirageApproval"}

  validates :type, :object_type, :object_id, :user_id, presence: true
  validates :object_id, uniqueness: { scope: [:type, :object_type, :user_id], :message => :already_exists }


  def object
    case object_type.to_s
    when "user"
      User.find_by(:id => object_id)
    when "dept"
      Dept.find_by(:id => object_id)
    end
  end

  def update_umpirage_approver
    @issues = Issue.where(status_id: IssueStatus::APPY_UMPIRAGE_STATUS, assigned_to_id: object_id, umpirage_approver_id: nil)
    @issues.update_all(umpirage_approver_id: user_id) if @issues.present?
  end

end
