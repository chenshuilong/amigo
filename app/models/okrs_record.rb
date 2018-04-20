class OkrsRecord < ActiveRecord::Base
  has_many :alter_records, :as => :alter_for, :dependent => :destroy, :inverse_of => :alter_for
  has_many :objects, class_name: 'OkrsObject', :as => :container, :dependent => :destroy
  has_many :results, :through => :objects
  has_many :supports, class_name: 'OkrsSupport', foreign_key: 'okrs_record_id'
  belongs_to :author, class_name: 'User', foreign_key: 'author_id'
  belongs_to :approver, class_name: 'User', foreign_key: 'approver_id'

  serialize :title_info, Hash

  scope :search_of_date, lambda { |arg| where("concat(okrs_records.year_of_title, '-', okrs_records.month_of_title) = ?", arg.to_s) }

  def do_save(params)
    status = false
    messages = []
    current_user = User.current
    current_dept = current_user.dept

    year = params[:name][:year] || Time.now.year
    month = params[:name][:month] || Time.now.month
    dept = Dept.find_by(id: params[:name][:dept].to_i).try(:orgNm) || current_dept.orgNm
    user = current_user.firstname
    okr_params = {}
    okr_params[:title] = "#{year}年#{month}月#{dept}#{user}OKRS"
    okr_params[:year_of_title] = year
    okr_params[:month_of_title] = month
    okr_params[:dept_of_title] = params[:name][:dept].to_i || current_dept.id.to_i
    okr_params[:author_id] = current_user.id
    okr_params[:dept_id] = current_dept.try(:id)
    okr_params[:status] = params[:approver].present? ? "approving" : "submitted"
    okr_params[:approver_id] = current_user.find_okr_approver.id

    old_object_uniq_keys = self.objects.map(&:uniq_key)
    new_object_uniq_keys = []
    old_result_uniq_keys = self.results.map(&:uniq_key)
    new_result_uniq_keys = []
    OkrsRecord.transaction do 
      if (objects = params[:object]).present?
        @okrs_record = self.assign_attributes(okr_params)
        deleted_supported_ids = {}
        objects.each do |k, v|
          if v[:name].present?
            new_object_uniq_keys << k
            if k.in?(old_object_uniq_keys)
              current_object = self.objects.find_by(uniq_key: k)
            else
              current_object = OkrsObject.new
            end

            current_object.uniq_key = k
            current_object.name = v[:name]
            self.objects << current_object

            if (key_results = v[:key_results]).present?
              result_uniq_keys = current_object.results.map(&:uniq_key)
              deleted_supported_ids[k] = {}
              key_results.each do |ki, vi|
                if vi[:name].present?
                  new_result_uniq_keys << ki
                  if ki.in?(result_uniq_keys)
                    current_result = current_object.results.find_by(uniq_key: ki)
                  else
                    current_result = OkrsKeyResult.new
                  end
                  current_result.uniq_key = ki
                  current_result.name = vi[:name]
                  if (supports = vi[:supported_by]).present?
                    last_result_supports = current_result.supports.map(&:user_id)
                    deleted_supported_ids[k][ki] = last_result_supports - vi[:supported_by].collect{|i| i.to_i}
                    supports.each do |support|
                      unless support.to_i.in?(last_result_supports)
                        user = User.find(support)
                        current_support = current_result.supports.build({user_id: support, user_name: user.firstname, container_type: "OkrsKeyResult"})
                      end
                    end
                  else
                    deleted_supported_ids[k][ki] = current_result.supports.map(&:user_id)
                  end
                  current_object.results << current_result
                else
                  messages << "目标 #{v[:name]} 下关键结果未填写信息!"
                end
              end
            else
              messages << "请在目标 #{v[:name]} 下添加关键结果!"
            end
          else
            messages = ["请填写目标信息和关键结果！"]
          end
        end
      else
        messages = ["请添加目标！"]
      end

      if messages.blank?
        self.save
        deleted_object_ids = OkrsObject.where(uniq_key: old_object_uniq_keys - new_object_uniq_keys).map(&:id)
        OkrsObject.where(id: deleted_object_ids).delete_all if deleted_object_ids.present?
        deleted_result_ids = OkrsKeyResult.where(uniq_key: old_result_uniq_keys - new_result_uniq_keys).map(&:id)
        OkrsKeyResult.where(id: deleted_result_ids).delete_all if deleted_result_ids.present?
        OkrsSupport.delete_invalid_supports(deleted_supported_ids)
        self.do_save_notes(params)
        self.send_approve_notification if self.status == "approving"
        status = true
      end
    end

    return status, messages
  end

  def table_info
    table_hash = {}
    objects.each do |object|
      table_hash[object.id] = {}
      table_hash[object.id][:id] = object.id
      table_hash[object.id][:name] = object.name
      table_hash[object.id][:uniq_key] = object.uniq_key
      table_hash[object.id][:results_count] = object.results.count
      table_hash[object.id][:results] = []
      i = 0
      object.results.each do |result|
        result_hash = {}
        result_hash[:index] = i
        result_hash[:id] = result.id
        result_hash[:name] = result.name
        result_hash[:uniq_key] = result.uniq_key
        result_hash[:supported_by] = result.supports.pluck(:user_name).join(", ")
        result_hash[:self_score] = (result.self_score.present? ? result.self_score.to_f : '') if %w(self_scoring other_scoring finished).include?(status)
        result_hash[:other_score] = (result.other_score.present? ? result.other_score.to_f : '') if %w(other_scoring finished).include?(status)
        table_hash[object.id][:results] << result_hash
        i = i + 1
      end
    end
    return table_hash
  end

  def do_save_notes(params)
    if params[:status].present?
      self.update_columns(status: params[:status])
      send_supported_notification if status == "self_scoring"
    end
    if params[:notes].present?
      @record = AlterRecord.new(alter_for: self, user_id: User.current.id)
      @record.details.build({prop_key: 'notes', value: params[:notes]})
      @record.save
    end

    return true, []
  end

  def send_approve_notification
    Notification.send_okr_record_approve_notification(self) if status == "approving"
  end

  def send_supported_notification
    recipients = supports.select(:user_id).pluck(:user_id).uniq
    if recipients.present?
      options = {okr: self}
      Notification.send_okr_record_supported_notification(recipients, options)
    end
  end

  def altered_attribute_names
    names = %w(notes)
  end

  def can_change_status?
    case status
    when "self_scoring"
      rest_count = results.where(self_score: nil).count
    when "other_scoring"
      rest_count = results.where(other_score: nil).count
    end
    rest_count == 0
  end

  def set_to_mine(obj, category)
    current_user = User.current
    okrs = current_user.okrs_records
    all_count = okrs.count
    finished_count = okrs.where(status: "finished").count
    submit_and_fail = okrs.where(status: %w(submitted failed))
    submit_and_fail_count = submit_and_fail.count

    if all_count == finished_count 
      okr_params = {}
      okr_params[:year_of_title] = Time.now.year
      okr_params[:month_of_title] = Time.now.month
      okr_params[:dept_of_title] = current_user.dept.id
      okr_params[:title] = "#{Time.now.year}年#{Time.now.month}月#{current_user.dept.orgNm}#{current_user.firstname}OKRS"
      okr_params[:status] = "submitted"
      okr_params[:author_id] = current_user.id
      okr_params[:approver_id] = current_user.find_okr_approver.id
      okr_params[:dept_id] = current_user.dept.id
      new_okr_record = OkrsRecord.new(okr_params)
    elsif submit_and_fail_count != 0
      new_okr_record = submit_and_fail.last
    else
      messages = "设置失败! 检测到您还有未完成的OKR。"
    end

    if new_okr_record.present?
      OkrsRecord.transaction do 
        new_object_params = {}
        new_object_params[:name] = obj.name
        new_object_params[:uniq_key] = Time.now.to_i * 1000
        new_object = new_okr_record.objects.build(new_object_params)
        new_result = new_object.results.build(new_object_params)
        new_okr_record.save
        messages = "设置成功！"
      end  
    end

    return messages
  end

  def self.recall(ids)
    status = false
    select_okrs = all.where(id: ids, status: "approving", author_id: User.current.id)
    if select_okrs.present?
      saved = OkrsRecord.transaction do 
        select_okrs.each do |okr|
          okr.update(status: "submitted")
          okr.send_recall_notification
        end
      end
      message = "操作成功！" if saved
      status = true if saved
    else
      message = "没有能撤回的OKR!"
    end
    return status, message
  end

  def send_recall_notification
    Notification.send_okr_record_recall_notification(self)
  end
end
