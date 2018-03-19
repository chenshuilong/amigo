class SpecAlterRecord < ActiveRecord::Base
  belongs_to :spec
  belongs_to :user

  NEW_RECORD      = 0
  UPDATE_RECORD   = 1
  DELETE_RECORD   = 2
  LOCKED_RECORD   = 3
  RESET_RECORD    = 4
  COLLECT_RECORD  = 5
  FREEZED_RECORD  = 6
  COPY_RECORD     = 7

  default_scope { order(created_at: :desc) }


  before_save   :update_type_by_copy
  before_create :update_type_by_copy

  def update_type_by_copy
    self.record_type = COPY_RECORD if self.prop_key.to_s.include?("copy")
  end
end
