class DocumentAttachment < ActiveRecord::Base

  belongs_to :attachment, :class_name => 'Attachment', :foreign_key => 'attachment_id'

end
