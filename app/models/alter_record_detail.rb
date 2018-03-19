class AlterRecordDetail < ActiveRecord::Base
  belongs_to :alter_record
  attr_protected :id

  scope :native_applist_details, -> { joins("INNER JOIN alter_records ON alter_records.id = alter_record_details.alter_record_id AND alter_records.alter_for_type = 'ApkBase'
                                             LEFT JOIN apk_bases ON apk_bases.id = alter_records.alter_for_id AND apk_bases.app_category = 10") }

  scope :apk_base_details, -> { joins("INNER JOIN alter_records ON alter_records.id = alter_record_details.alter_record_id AND alter_records.alter_for_type = 'ApkBase'
                                       LEFT JOIN apk_bases ON apk_bases.id = alter_records.alter_for_id AND apk_bases.app_category in (1, 4, 10)") }

  def value=(arg)
    write_attribute :value, normalize(arg)
  end

  def old_value=(arg)
    write_attribute :old_value, normalize(arg)
  end

  private

  def normalize(v)
    case v
      when true
        "1"
      when false
        "0"
      when Date
        v.strftime("%Y-%m-%d")
      else
        v
    end
  end
end
