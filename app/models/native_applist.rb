class NativeApplist < ActiveRecord::Base
  has_many :alter_records, :as => :alter_for, :dependent => :destroy, :inverse_of => :alter_for
  belongs_to :author, :class_name => 'User'

  validates :name, :apk_name, :cn_name, :desktop_name, :description, :developer, presence: true
  validates :apk_name, uniqueness: true, if: :has_apk_name?

  after_save :create_alter

  scope :version_publish_apk_info, lambda { |arg|
    select("native_applists.id, name, cn_name, desktop_name, description, developer, version_applists.apk_name,
       version_applists.apk_interior_version, version_applists.apk_permission, version_applists.apk_removable, deleted")
    .from("(
            select id, max(native_applists.created_at) as maxcreated_at
            from native_applists
            group by apk_name
          ) as x")
    .joins("inner join native_applists on native_applists.created_at = x.maxcreated_at
            left join version_applists on version_applists.apk_name = native_applists.apk_name")
    .where("version_id = #{arg.to_i}")
  }

  def has_apk_name?
    NativeApplist.where(deleted: false, apk_name: apk_name).present?
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
    NativeApplist.column_names - %w(id author_id deleted deleted_at created_at updated_at)
  end

  def generate_alter_record(type)
    old_value = type == "create" ? nil : name
    value     = type == "create" ? name : nil
    @record = AlterRecord.create(alter_for_id: id, alter_for_type: self.class.name, user_id: User.current.id)
    @record.details.build(property: type, prop_key: "name", old_value: old_value, value: value)
    @record.save
  end

  def self.generate_rows_json
    rows = {}
    self.all.each do |app|
      rows[app.name.squish] = {"cn_name": app.cn_name.to_s, "desktop_name": app.desktop_name.to_s, "description": app.description.to_s, "developer": app.developer.to_s, "type": "google"}
    end
    return rows
  end

  def self.generate_apk_info
    @apk_infos = self.all
    lists = VersionPermission.where.not(deleted:true, name:"remove_notes").pluck(:name, :meaning).to_h
    rows = {}
    @apk_infos.each do |apk_info|
      list = []
      if apk_info.apk_permission.present?
        @permissions = apk_info.apk_permission.split(";")
        @permissions.each do |per|
          list.push(lists[per].present? ? lists[per] : per) 
        end
      end
      apk_permission = list.join(" ")
      apk_removable = apk_info.apk_removable == 0 ? "否" : "是"
      rows[apk_info.name.squish] = {"app_name": apk_info.name, 
                                    "app_version": apk_info.apk_interior_version, 
                                    "apk_permission": apk_permission, 
                                    "apk_removable": apk_removable, 
                                    "deleted": apk_info.deleted}
    end
    return rows
  end

end
