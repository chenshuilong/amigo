class FlowFile < ActiveRecord::Base
  has_many :flow_file_attachments, foreign_key: "flow_file_id"
  has_many :alter_records, :as => :alter_for, :dependent => :destroy, :inverse_of => :alter_for
  belongs_to :author, :class_name => "User", foreign_key: "author_id"
  
  acts_as_attachable :view_permission => true,
                     :edit_permission => true,
                     :delete_permission => true

  validate :validate_params

  after_save :create_alter

  scope :file_attachments, lambda { |id|
    sql = id.present? ? "flow_files.id != #{id}" : "" 
    joins(:attachments).where(attachments: {deleted: false})
    .select("name, GROUP_CONCAT( CONCAT_WS(',', attachments.filename, attachments.id) SEPARATOR ',') as attachment_list")
    .where(sql)
    .group("container_id")
  }
  
  def validate_params
    errors.add(:name, "为必填") if name.blank?
    errors.add(:file_type, "类型 为必填") if file_type_id.blank?
    errors.add(:version, "为必填") if version.blank?
    errors.add(:status, "状态 为必填") if file_status_id.blank?
    errors.add(:attachments, "未上传流程文件") if saved_attachments.blank? && attachments.where(deleted: false).count == 0
  end

  def do_save(file_params, attachment_params, flow_file_attas=[])
    @file = self
    @alter_record = @file.init_alter
    @file.assign_attributes(file_params)
    @file.no = FlowFile.last_no(@file.file_type_id) if no.blank?
    saved = false
    
    if @file.file_type_id.present?
      @file_type = FlowFileType.find(@file.file_type_id)
      @file.file_type_code = @file_type.code
      @file.file_type_name = @file_type.name
    end

    if @file.file_status_id.present?
      @file_status = FlowFileStatus.find(@file.file_status_id)
      @file.file_status_name = @file_status.name
    end

    #add, delete, modify record of flow_file_attachments
    deleted_relates, relate_details, relate_files = @file.update_flow_file_attachments(@alter_record, flow_file_attas)
    #add, delete, modify record of attachments
    delete_attas, atta_details, save_files, abandon_atta_ids = update_attachments(@file, @alter_record, attachment_params)

    FlowFile.transaction do 
      @alter_record.details << atta_details
      @alter_record.details << relate_details
      @file.save_attachments(save_files) if save_files.present?
      @file.flow_file_attachments << relate_files if relate_files.present?
      saved = @file.save

      if saved
        if delete_attas.present?
          @file.attachments.where(uniq_key: delete_attas.uniq).update_all(deleted: true, deleted_by_id: User.current.id, deleted_at: Time.now)
        end
        if deleted_relates.present?
          @file.flow_file_attachments.where(attachment_id: deleted_relates, status: 'active').update_all(status: "deleted")
        end
        if abandon_atta_ids.present?
          FlowFileAttachment.update_abandoned(abandon_atta_ids, 'flow_file_delete')
        end
      end
    end

    return saved
  end

  #流程文件变更及变更记录生成
  def update_attachments(file, alter_record, attachment_params)
    delete_attas = []
    details = []
    save_files = {}
    abandon_attas = []
    if attachment_params.present?
      exist_attas = file.attachments.where(deleted: false).map(&:uniq_key) #已存在文件的uniq_key
      current_attas = [] #当前上传文件的uniq_key
      new_details = []
      new_save_attachment = {}
      #新增文件的处理
      attachment_params["flow_file"].each do |k, v|
        atta_id = v["token"].split(".")[0]
        uniq_key = v["token"].split(".")[1]
        current_attas << uniq_key
        unless uniq_key.in?(exist_attas)
          new_atta = Attachment.find_by(uniq_key: uniq_key)
          if new_atta.present?
            new_save_attachment[atta_id] = v
            details << alter_record.details.new(prop_key: "attachment", property: "new", value: new_atta.id)
          end
        end
      end
      
      save_files = new_save_attachment if new_save_attachment.present?
      alter_record.details << details
      delete_attas = exist_attas - current_attas
      delete_atta_ids = []
      #删除文件的处理
      if delete_attas.present?
        delete_attas.each do |atta|
          delete_atta = Attachment.find_by(uniq_key: atta)
          if delete_atta.present?
            delete_atta_ids << delete_atta.id
            file.attachments.find_by(uniq_key: atta).assign_attributes(deleted: true, deleted_by_id: User.current.id, deleted_at: Time.now)
            details << alter_record.details.new(prop_key: "attachment", property: "delete", value: delete_atta.id)
          end
        end

        abandon_atta_ids = find_abandon_atta_ids(delete_atta_ids)
      end
    end

    return delete_attas, details, save_files, abandon_atta_ids
  end

  #相关附件变更及变更记录生成
  def update_flow_file_attachments(alter_record, flow_file_attas)
    @active_relates = flow_file_attachments.where(status: 'active')
    exist_relates = @active_relates.pluck(:attachment_id).map(&:to_s)
    current_relates = flow_file_attas || []
    deleted_relates = exist_relates - current_relates
    new_relates = current_relates - exist_relates
    relate_details = []
    relate_files = []
    (deleted_relates + new_relates).uniq.each do |relate|
      current_relate = @active_relates.find_by(attachment_id: relate)
      if current_relate.present?
        if relate.in?(deleted_relates)
          relate_details << alter_record.details.new(prop_key: "flow_file_attachment", property: "delete", value: relate)
        end
      else
        atta = Attachment.find(relate)
        relate_params = {}
        relate_params[:attachment_id] = relate
        relate_params[:parent_flow_file_id] = atta.container_id
        relate_params[:status] = "active"
        relate_files << @file.flow_file_attachments.new(relate_params)
        relate_details << alter_record.details.new(prop_key: "flow_file_attachment", property: "new", value: relate)
      end
    end
    return deleted_relates, relate_details, relate_files
  end

  def self.last_no(file_type_id=nil)
    @file_type_id = file_type_id || FlowFileType.try(:first).try(:id) || 0
    old_last_no = all.where(file_type_id: @file_type_id).pluck(:no)[-1].to_i
    new_last_no = old_last_no + 1
    i = new_last_no.to_s.length >= 3 ? 0 : (3 - new_last_no.to_s.length)
    last_no = "#{'0'*i}#{new_last_no}"
  end

  def do_abandon
    FlowFile.transaction do
      @file = self 
      @alter_record = @file.init_alter
      abandon_status = FlowFileStatus.find_by(name: "废弃")
      abandon_status = FlowFileStatus.create(name: "废弃", author_id: User.current.id) if abandon_status.blank?
      @file.assign_attributes(file_status_id: abandon_status.id, file_status_name: abandon_status.name)

      atta_ids = attachments.map(&:id)
      abandon_atta_ids = find_abandon_atta_ids(atta_ids)
      if @file.save
        FlowFileAttachment.update_abandoned(abandon_atta_ids, 'flow_file_abandon') if abandon_atta_ids
      end
    end
  end

  def find_abandon_atta_ids(atta_ids)
    abandon_atta_ids = FlowFileAttachment.where(parent_flow_file_id: id, attachment_id: atta_ids, status: "active").pluck(:id)
    return abandon_atta_ids
  end

  def init_alter(notes = "")
    @current_alter ||= AlterRecord.new(:alter_for => self, :user => User.current)
  end

  # Returns the current journal or nil if it's not initialized
  def current_alter
    @current_alter
  end

  def create_alter
    if current_alter
      current_alter.save
    end
  end

  def altered_attribute_names
    names = %w(name version file_type_id file_status_id use)
  end

  def self.get_no(file_id=nil, file_type_id=nil)
    @file_type = FlowFileType.find_by(id: file_type_id) || FlowFileType.first
    if file_id.present?
      @file = FlowFile.find_by(id: file_id)
      no = "OS-#{@file_type.try(:code)}-#{@file.try(:no)}"
    else
      no = "OS-#{@file_type.try(:code)}-#{FlowFile.last_no(@file_type.try(:id))}"
    end
    return no
  end
end
