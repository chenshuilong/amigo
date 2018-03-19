class ApkBaseCategory < Enumeration
  has_many :apks, class_name: "ApkBase", :foreign_key => 'category_id'

  OptionName = :enumeration_apk_bases_categories

  def option_name
    OptionName
  end

  def objects_count
    apks.count
  end

  def transfer_relations(to)
    apks.update_all(:category_id => to.id)
  end

  def self.default
    d = super
    d = first if d.nil?
    d
  end
end
