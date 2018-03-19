class DemandSourceCategory < Enumeration
  has_many :sources, class_name: "Demand", :foreign_key => 'sub_category_id'

  OptionName = :enumeration_demand_source_categories

  def option_name
    OptionName
  end

  def objects_count
    sources.count
  end

  def transfer_relations(to)
    sources.update_all(:sub_category_id => to.id)
  end

  def self.default
    d = super
    d = first if d.nil?
    d
  end
end
