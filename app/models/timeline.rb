class Timeline < ActiveRecord::Base
  belongs_to :container, :polymorphic => true

  validates_presence_of :name

  scope :choice, lambda { select("DISTINCT #{table_name}.name") }
end
