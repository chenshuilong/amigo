class NewFeature < ActiveRecord::Base

  NEWFEATURE_CATEGORY = {"1" => "新增", "2" => "修复", "3" => "优化", "4" => "补丁"}
  validates :description, presence: true

  default_scope { order(created_at: :desc) }

  def category_name
    NEWFEATURE_CATEGORY[self.category.to_s]
  end

end
