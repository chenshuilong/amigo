class ReportConditionHistory < ActiveRecord::Base
  belongs_to :user
  belongs_to :condition, :foreign_key => "from_id"

  default_scope -> { order(updated_at: :desc) }
end
