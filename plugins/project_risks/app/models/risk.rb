class Risk < ActiveRecord::Base
  belongs_to :project
  belongs_to :user
  has_many :risk_measures, dependent: :destroy
  accepts_nested_attributes_for :risk_measures, allow_destroy: true

  DEPARTS = ["驱动", "软件", "相机"]
  CATES =  ["技术", "质量", "进度"]

  validates :project_id, :department, :category, :description, :user_id, presence: true
  validates_associated :risk_measures
  validate :check_departments, :check_category
  default_scope -> { order(created_at: :asc) }

  def check_departments
    errors.add(:department, "部门错误") unless DEPARTS.include?(self.department)
  end

  def check_category
    errors.add(:category, "类别错误") unless CATES.include?(self.category)
  end

end
