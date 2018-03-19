class Production < Project
  ROLES = {:bug_owner => [57, 'Bug Owner'], :bmjl => [56, "部门经理"], :app_spm => [27, "APP-SPM"], :app_pd => [20, "APP-PD"], :app_po => [23,"APP-PO"], 
           :app_ued => [21, "APP-UED"], :app_de => [24,"APP-DE"], :app_tester => [22, "APP-测试工程师"]}

  has_many :spec_versions

  default_scope { where(category: 4).order("production_type,name") }

  scope :useful, lambda { where("production_type <> #{Project::PROJECT_PRODUCTION_TYPE[:other]}") }
  scope :classify, lambda { |active|
    status_sql = active ? " = 1" : " <> 1"
    select("#{table_name}.production_type,#{self.convert_production_type} type_name, #{self.count_production_type}").where("#{table_name}.status #{status_sql}").group("#{table_name}.production_type")
  }
  scope :preload_apps, lambda { where(production_type: PROJECT_PRODUCTION_TYPE[:preload]) }
  scope :resource_apps, lambda { where(production_type: PROJECT_PRODUCTION_TYPE[:resource]) }
  scope :sdk_apps, lambda { where(production_type: PROJECT_PRODUCTION_TYPE[:jar]) }

  private

  def self.convert_production_type
    "case " <<
        Project::PROJECT_PRODUCTION_TYPE.map { |type, value|
          label_type = "project_production_type_#{type}".to_sym
          "when #{table_name}.production_type = #{value} then '#{l(label_type)}'"
        }.join(' ') << " end"
  end

  def self.count_production_type
    "count(case " <<
        Project::PROJECT_PRODUCTION_TYPE.map { |type, value|
          "when #{table_name}.production_type = #{value} then #{table_name}.id"
        }.join(' ') << " end) amount"
  end
end
