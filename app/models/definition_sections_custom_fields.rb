class DefinitionSectionsCustomFields < ActiveRecord::Base
  has_many :definition_sections
  has_many :definition_custom_fields

  # default_scope { order(sort: :asc) }
  scope :configrated, -> {select("#{table_name}.id,definition_sections.name m_name,custom_fields.id cf_id,custom_fields.name cf_name").
      joins("LEFT JOIN definition_sections ON definition_sections.id = definition_sections_custom_fields.definition_section_id
             INNER JOIN custom_fields ON custom_fields.id = definition_sections_custom_fields.custom_field_id AND custom_fields.type = 'DefinitionCustomField'").
      order("definition_sections_custom_fields.definition_section_id,SUBSTRING_INDEX(custom_fields.name,'|',1),sort")}

  scope :fields, -> {select("cf.name,dscf.custom_field_id").joins("dscf INNER JOIN custom_fields cf ON cf.id = dscf.custom_field_id")}
end
