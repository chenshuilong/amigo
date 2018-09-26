class FlowFileStatus < ActiveRecord::Base
  validates :name, presence: true
  validates_uniqueness_of :name

  def can_delete?
    FlowFile.where(file_status_id: id).count == 0
  end
end
