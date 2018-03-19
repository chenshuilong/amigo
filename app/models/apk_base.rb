class ApkBase < ActiveRecord::Base
  has_many :alter_records, :as => :alter_for, :dependent => :destroy, :inverse_of => :alter_for
  has_many :tasks, :as => :container
  has_one :project_apk, class_name: 'ProjectApk', foreign_key: 'apk_base_id'
  belongs_to :apk_base_category, :class_name => "ApkBaseCategory", foreign_key: "category_id"
  belongs_to :author, :class_name => 'User'

  APK_BASE_OS_CATEGORY = {android: 1}
  APK_BASE_APP_CATEGORY = {:app => 1, :preload => 4, :google => 10}
  APK_BASE_REMOVABLE = {:yes => 1, :no => 0, :no_integration => 2}
  APK_BASE_ANDROID_PLATFORM = {:other_platform => 1, :o_platform => 2}

  validate :validate_base_info
  validate :validate_name_format
  validates :notes, presence: true, if: :native_app?

  after_save :create_alter

  scope :search, lambda { 
    select("apk_bases.id, apk_bases.name, apk_bases.cn_name, apk_bases.en_name, apk_bases.cn_description, apk_bases.en_description, apk_bases.desktop_name, apk_bases.package_name,
            apk_bases.developer, apk_bases.os_category, apk_bases.app_category, apk_bases.removable, apk_bases.desktop_icon, apk_bases.android_platform, apk_bases.integrated,
            case apk_bases.os_category when 1 then 'Android' end as os_category_text,
            case apk_bases.app_category when 1 then 'APK' when 4 then '预装应用' when 10 then 'Google原生应用' else '' end as app_category_text,
            case apk_bases.android_platform when 1 then 'N及之前平台' when 2 then 'O平台' end as android_platform_text,
            case apk_bases.removable when 0 then '否' when 1 then '是' when 2 then '不集成' else '' end as removable_text,
            case apk_bases.desktop_icon when 0 then '否' when 1 then '是' else '' end as desktop_icon_text,
            case apk_bases.integrated when 0 then '否' when 1 then '是' else '' end as integrated_text,
            projects.name as production, project_apks.project_id as production_id, enumerations.name as category")
    .joins("LEFT JOIN project_apks ON project_apks.apk_base_id = apk_bases.id
           LEFT JOIN projects ON projects.id = project_apks.project_id
           LEFT JOIN enumerations ON apk_bases.category_id = enumerations.id AND enumerations.type = 'ApkBaseCategory'")}

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
    ApkBase.column_names - %w(id author_id created_at updated_at app_category)
  end

  def self.import(file)
    sheet = Roo::Excelx.new(file, packed: false, file_warning: :ignore)

    sheet.each do |hash|
      next if hash[0].blank? || hash[0] == '应用名称'
      apk_params = {}
      apk_params[:cn_name]        = hash[0]
      apk_params[:name]           = hash[1].squish
      apk_params[:package_name]   = hash[2].squish
      apk_params[:cn_description] = hash[3]
      apk_params[:developer]      = hash[4]
      apk_params[:desktop_name]   = hash[0]
      apk_params[:os_category]    = 1
      apk_params[:author_id]      = User.current.id

      apk = ApkBase.find_by_name(hash[1].squish)

      unless apk.present?
        ApkBase.create(apk_params)
      end
    end
  end

  def validate_name_format(new_integrated=nil)
    errors.add(:name, :blank)                 if name.blank?
    errors.add(:name, :apk_base_name_invalid) unless name.include?(".apk")
  end

  def validate_base_info
    errors.add(:cn_name, :blank)              if cn_name.blank? && integrated != false
    errors.add(:cn_description, :blank)       if cn_description.blank? && integrated != false
    errors.add(:developer, :blank)            if developer.blank? && integrated != false
    errors.add(:desktop_name, :blank)         if desktop_name.blank? && integrated != false
    errors.add(:package_name, :blank)         if package_name.blank? && integrated != false
    errors.add(:category_id, :blank)          if category_id.blank? && integrated != false
  end

  def native_app?
    app_category.to_i == 10
  end

  def do_save(method, params, project=nil)
    apk_base = self
    send_task = false
    saved = false
    change_params = {}

    case method
    when "add"
      apk_base.integrated = params[:integrated]
      if apk_base.app_category.to_i == 1 && !apk_base.integrated
        apk_base.name = params[:name]
        apk_base.android_platform = params[:android_platform]
        saved = apk_base.save
      else
        apk_base.assign_attributes(params)
        apk_base.android_platform = %w(1 10).include?(app_category.to_s) ? 1 : params[:android_platform] 
        saved = apk_base.save
      end

      send_task = true if self.app_category.to_i == 1 && apk_base.integrated == true && params[:android_platform].to_i == 2 && saved
      send_task = true if self.app_category.to_i == 10 && params[:android_platform].to_i == 2 && saved
    when "modify"
      case self.app_category
      when 1
        changed_platform = false
        changed_integrated = false
        old_android_platform = self.android_platform.to_i
        new_android_platform = params[:android_platform].to_i
        old_integrated = self.integrated.to_s
        new_integrated = params[:integrated].to_s
        if old_android_platform != new_android_platform
          changed_platform = true
          change_params[:android_platform] = {old: old_android_platform, new: new_android_platform}
        end

        if old_integrated != new_integrated
          changed_integrated = true
          change_params[:integrated] = {old: old_integrated, new: new_integrated}
        end

        if changed_platform || changed_integrated
          if old_android_platform == 2 && old_integrated == 'true'
            send_task = true
          else
            send_task = true if new_android_platform == 2 && new_integrated == 'true'
          end
        end

        apk_base.init_alter
        apk_base.assign_attributes(params)
        if send_task
          # apk_base.android_platform = old_android_platform if changed_platform
          # apk_base.integrated = old_integrated if changed_integrated
          if old_integrated == "false" && changed_integrated
            apk_base.validate_base_info
            apk_base.clear_base_info
          end
          apk_base.android_platform = old_android_platform if changed_platform
          apk_base.integrated = old_integrated if changed_integrated
        else
          if new_integrated == "false" && changed_integrated
            apk_base.clear_base_info
          end
        end
        if errors.present?
          saved = false
          apk_base.integrated = old_integrated
        else
          saved = apk_base.save
        end
      when 4
        apk_base.init_alter
        apk_base.assign_attributes(params)
        saved = apk_base.save
      when 10
        old_android_platform = self.android_platform.to_i
        new_android_platform = params[:android_platform].to_i
        send_task = true if old_android_platform != new_android_platform && (old_android_platform == 2 || new_android_platform == 2)

        apk_base.init_alter
        apk_base.assign_attributes(params)
        apk_base.android_platform = old_android_platform if send_task
        saved = apk_base.save
      end
    when "delete"
      case self.app_category
      when 1
        if self.integrated == true && self.android_platform.to_i == 2
          send_task = true
        else
          saved = do_delete
        end
      when 4
        saved = do_delete
      end
    end 

    generate_approve_task(method, params, change_params, project) if send_task && errors.blank?
    result = {saved: saved, messages: errors.messages}
    return result
  end

  def do_delete
    @project_apk = project_apk
    @project_apk.deleted = true
    @project_apk.deleted_by_id = User.current.id
    @project_apk.deleted_at = Time.now
    return @project_apk.save
  end

  def generate_approve_task(method, params=nil, change_params=nil, project=nil)
    rows = {}
    rows[:change] = change_params
    rows[:content] = {}
    rows[:method] = method
    case method
    when 'add'
      rows[:content][:apk_base_old] = params
      rows[:content][:apk_base] = rows[:content][:apk_base_old]
    when 'modify'
      rows[:content][:apk_base_old] = self.attributes.delete_if{|k,v| %(id en_name en_description created_at updated_at).include?(k)}
      rows[:content][:apk_base] = params
    when 'delete'
      rows[:content][:apk_base_old] = self.attributes.delete_if{|k,v| %(id en_name en_description created_at updated_at).include?(k)}
      rows[:content][:apk_base] = rows[:content][:apk_base_old]
    end

    key = APK_BASE_ANDROID_PLATFORM.key(params[:android_platform].to_i)
    text = l("apk_base_android_platform_#{key}")
    user = approver
    @task = Task.create({container: self, name: text, assigned_to_id: user.id, author_id: User.current.id, status: 24, description: rows.to_json, is_read: false})
    options = {:apk_base => self, :apk_base_info => @task.build_apk_base_info(project)}
    case app_category
    when 1
      options[:project] = project
      receivers = [User.find_by_firstname("刘小杰"), User.find_by_firstname("韩保君"), "li_qian@gionee.com"]
    when 10
      receivers = [User.find_by_firstname("韩保君"), "li_qian@gionee.com"]
    end

    begin
      Mailer.apk_base_approve_notification(receivers, options).deliver
    rescue
      receivers.each do |receiver|
        begin
          Mailer.apk_base_approve_notification(receiver, options).deliver
        rescue
          next
        end
      end
    end
  end

  def approver
    case app_category
    when 1
      user = User.find_by_firstname("刘小杰")
    when 10
      user = User.find_by_firstname("韩保君")
    end
    return user
  end

  def clear_base_info
    self.cn_name = nil
    self.cn_description = nil
    self.desktop_name = nil
    self.desktop_icon = nil
    self.developer = nil
    self.package_name = nil
    self.category_id = nil
    self.removable = nil
    self.notes = nil
    return self
  end
end
