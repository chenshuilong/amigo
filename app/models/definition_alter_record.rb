class DefinitionAlterRecord < ActiveRecord::Base
  belongs_to :product_definitions
  belongs_to :users

  NEW_RECORD      = 0
  UPDATE_RECORD   = 1
  DELETE_RECORD   = 2

  default_scope { order(created_at: :desc) }
end
