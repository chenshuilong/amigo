class FlowFileAttachment < ActiveRecord::Base
  belongs_to :flow_file
  belongs_to :attachment, foreign_key: "attachment_id"

  def self.update_abandoned(ids, prop_key)
    @flow_file_attachments = FlowFileAttachment.where(id: ids, status: 'active').group("flow_file_id")
    @flow_file_attachments.each do |ffa|
      ff = ffa.flow_file
      current_ffas = ff.flow_file_attachments.where(id: ids)
      alter_record = ff.init_alter
      current_ffas.each do |cffa|
        alter_record.details.new(prop_key: prop_key, value: cffa.id)
      end
      current_ffas.update_all(status: 'abandoned')
      ff.save
    end
  end
end
