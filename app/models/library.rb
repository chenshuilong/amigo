class Library < ActiveRecord::Base
  has_one :task, :as => :container, :dependent => :destroy
  has_many :alter_records, :as => :alter_for, :dependent => :destroy, :inverse_of => :alter_for
  has_many :library_files
  belongs_to :container, :class_name => "Patch"
  belongs_to :user

  validates :path, uniqueness: { scope: [:container_id, :name], :message => :already_exists }, if: :uniq_info?

  #serialize :files, Array

  after_save :create_alter

  def uniq_info?
    !files.present?
  end

  def init_alter(notes = "")
    @current_alter ||= AlterRecord.new(:alter_for => self, :user => User.current, :notes => notes)
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
    Library.column_names - %w(id container_id container_type created_at updated_at)
  end

  def send_task_to_duty
    if %w(update_failed merge_failed push_failed).include?(status) 
      if task.present?
        task.update(status: status, is_read: false)
      else
        Task.create(container_id: id, container_type: self.class.name, name: container.patch_no, assigned_to_id: user_id, due_date: container.due_at, status: status)
      end

      send_notification
    end
  end

  def status_text(notes = nil)
      case status
      when 'update_failed'
        @notes = notes || "Patch Jenkins 自动升级gionee_update_master记录"
        @value = name.to_s + " 升级 gionee_update_master失败"
      when 'merge_failed'
        @notes = notes || "Patch Jenkins merge代码到gionee_master记录"
        @value = name.to_s + " merge 代码到gionee_master失败"
      when 'push_failed'
        @notes = notes || "Patch Jenkins push代码到gionee_master记录"
        @value = name.to_s + " push 代码到gionee_master失败"
      when 'update_success'
        @notes = notes
        @value = user.firstname.to_s + "对 " + name.to_s + " 完成gionee_update_master合入"
      when 'merge_success'
        @notes = notes
        @value = user.firstname.to_s + "对 " + name.to_s + " 完成gionee_master合入"
      when 'push_success'
        @notes = notes
        @value = user.firstname.to_s + "对 " + name.to_s + " 完成gionee_master代码push"
      end
      return @notes, @value
  end

  def check_all_libraries
    case status
    when "push_success"
      push_faileds = container.libraries.where(status: "push_failed")
      container.update_status_done unless push_faileds.present?
    else
      faileds = container.libraries.where(status: ["update_failed", "merge_failed"])
      container.do_jenkins_job("job3") unless faileds.present?
    end
  end

  def send_notification
    options = {:library => self}
    receivers = [user]

    begin
      Mailer.library_failed_notification(receivers, options).deliver
    rescue
      receivers.each do |receiver|
        begin
          Mailer.library_failed_notification(receiver, options).deliver
        rescue
          next
        end
      end
    end
  end

  def all_libraries
    if uniq_key.present?
      container.libraries.where("libraries.name = '#{self.name}' AND libraries.path = '#{self.path}' AND (libraries.id = '#{self.uniq_key}' OR libraries.uniq_key = '#{self.uniq_key}')")
    else
      container.libraries.where("libraries.name = '#{self.name}' AND libraries.path = '#{self.path}' AND (libraries.id = '#{self.id}' OR libraries.uniq_key = '#{self.id}')")
    end
  end

  def update_status_by_files(old_status, new_status)
    Library.transaction do 
      all_libraries.update_all(status: new_status)
      faileds = container.libraries.where(status: old_status).count
      case new_status
      when 'update_success'
        container.do_jenkins_job('postcompile') if faileds == 0
      when 'merge_success', 'push_success'
        if faileds == 0
          container.do_jenkins_job('unlock', unlock: 'gionee_update_master') 
          container.do_jenkins_job('unlock', unlock: 'gionee_master')
          container.update(status: "success", actual_due_at: Time.now)
          AlterRecord.create(alter_for: container, notes: "Patch合入任务完成！")
        end
      end
    end
  end

  def update_library_infos(new_status)
    Library.transaction do
      all_libraries.update_all(status: new_status)
      case new_status
      when "update_success"
        old_status = "update_failed"
        faileds = container.libraries.where(status: old_status).count
        container.do_jenkins_job('postcompile') if faileds == 0
      when "merge_success", "push_success"
        old_status = new_status == "merge_success" ? "merge_failed" : "push_failed"
        faileds = container.libraries.where(status: old_status).count
        if faileds == 0
          container.do_jenkins_job('unlock', unlock: 'gionee_update_master') 
          container.do_jenkins_job('unlock', unlock: 'gionee_master')
          container.update(status: "success", actual_due_at: Time.now)
          AlterRecord.create(alter_for: container, notes: "Patch合入任务完成！")
        end
      end
      #Patch history
      notes = "Name: #{name}, Path: #{path}库"+ l("library_status_#{old_status}") + "，#{user.firstname}已确认结果为" + l("library_status_#{new_status}") + "!"
      @record = AlterRecord.new(alter_for: container, notes: "gionee_update "+l("library_status_#{old_status}")+"结果更新")
      @record.details.build(value: notes)
      @record.save
    end
  end
end