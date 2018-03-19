class DemandCategory < Enumeration
  has_many :demands, :foreign_key => 'category_id'

  OptionName = :enumeration_demand_categories

  def option_name
    OptionName
  end

  def objects_count
    demands.count
  end

  def transfer_relations(to)
    demands.update_all(:category_id => to.id)
  end

  def self.default
    d = super
    d = first if d.nil?
    d
  end
end
