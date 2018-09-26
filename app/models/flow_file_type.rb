class FlowFileType < ActiveRecord::Base
  validates :name, :code, presence: true
  validates_uniqueness_of :code, scope: :name

  def can_delete?
    FlowFile.where(file_type_id: id).count == 0
  end
end
