class Definition < ActiveRecord::Base
  belongs_to :project
  has_many   :definition_custom_values
  has_many   :definition_alter_records
  has_many   :definition_sections

  acts_as_attachable :view_permission => :view_definition,
                     :edit_permission => :manage_product_definition,
                     :delete_permission => :manage_product_definition

  scope :table_columns, -> {
    columns.map { |c| c.name.to_s.to_sym }
  }

  def auto_version
    version_column = self.definition_custom_values.find_by_custom_field_id(DefinitionCustomField.defintion_version.id)
    version_column ? (version_column.value.to_s.start_with?("0.") ? version_column.value.to_s.succ : version_column.value) : "0.0.1"
  end

  def product_version
    version_column = self.definition_custom_values.find_by_custom_field_id(DefinitionCustomField.defintion_version.id)
    version_column ? version_column.value : ""
  end

  def self.init(project_id)
    if Definition.find_by_project_id(project_id).blank?
      pd = Definition.new
      pd.project_id = project_id
      pd.save
    end
  end
end
