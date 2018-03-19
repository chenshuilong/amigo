class Tool < ActiveRecord::Base
  belongs_to :author, :class_name => 'User'
  belongs_to :provider, :class_name => 'User'

  validates :name, :provider_id, :description, presence: :true
  validate :validate_attachment

  acts_as_attachable :view_permission => true,
                     :edit_permission => true,
                     :delete_permission => true

  def validate_attachment
    tool_url = saved_attachments.select{|a| a.extra_type == "tool_url"}
    errors.add(:tool, "工具必须上传") if tool_url.blank? && new_record?
    return errors
  end

  def do_delete
    @tool = self
    Tool.transaction do 
      @tool.attachments.delete_all
      files = "#{Attachment::IPS['3'][:path]}/#{@tool.id}"
      FileUtils.rm_rf(files)
      @tool.destroy
    end
  end

  def tool_urls
    url = {}
    attachments.each do |atta|
      url[atta.extra_type] = {}
      url[atta.extra_type][:url] = File.join(Attachment::IPS[atta.ftp_ip.to_s][:ftp], "#{id}/#{atta.id}/#{atta.disk_filename}") if atta.ftp_ip.present?
      url[atta.extra_type][:status] = atta.ftp_ip.present? ? "done" : "doing"
    end
    return url
  end
end
