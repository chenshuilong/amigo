class ReportCondition < ActiveRecord::Base
  belongs_to :condition, :foreign_key => "condition_id"
end
