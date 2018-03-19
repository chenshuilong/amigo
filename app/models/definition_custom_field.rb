class DefinitionCustomField < CustomField
  belongs_to :module_feild

  default_scope { order(position: :asc) }

  PRODUCT_DEFINTION_VERSION = "版本号（产品定义）"

  def type_name
    :label_definition_plural
  end

  def self.defintion_version
    self.find_by_name(PRODUCT_DEFINTION_VERSION)
  end

  def self.all
    CustomField.where("type = 'DefinitionCustomField' and id > 0").order(position: :asc)
  end
end
