class RiskMeasure < ActiveRecord::Base
  belongs_to :risk
  validates :content, :finish_at, presence: true

end
