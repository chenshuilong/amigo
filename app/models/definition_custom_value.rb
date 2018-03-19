class DefinitionCustomValue < ActiveRecord::Base
  belongs_to :product_definition

  # after_create :init_definiton_version

  scope :definition_custom_fields, lambda { |product_definition_id, parent_id|
    select("definition_custom_values.id,module.name module_name,custom_fields.id cf_id,custom_fields.name,SUBSTRING_INDEX(custom_fields.name,'|',1) main_name,
            sort,custom_fields.field_format,custom_fields.possible_values,definition_custom_values.value").
    joins("LEFT JOIN custom_fields ON custom_fields.id = definition_custom_values.custom_field_id AND custom_fields.type = 'DefinitionCustomField'
           LEFT JOIN definition_sections module ON module.id = definition_custom_values.definition_section_id
           LEFT JOIN definition_sections parent_module ON module.parent_id = parent_module.id
           LEFT JOIN definitions ON definitions.id = definition_custom_values.definition_id
           INNER JOIN projects ON projects.id = definitions.project_id").
    where("definitions.id = #{product_definition_id} and parent_module.id in (#{parent_id})").
    order("module.id,custom_fields.position,definition_custom_values.id,custom_fields.name")
  }

  scope :definition_custom_fields_group, lambda { |product_definition_id, parent_id|
    select("module.name module_name,SUBSTRING_INDEX(custom_fields.name,'|',1) main_name,GROUP_CONCAT(definition_custom_values.id) dvf_ids,
            GROUP_CONCAT(custom_fields.id) cf_ids,GROUP_CONCAT(SUBSTRING_INDEX(custom_fields.name,'|',-1)) cf_names,GROUP_CONCAT(custom_fields.field_format) cf_formats,
            GROUP_CONCAT(CASE WHEN LENGTH(definition_custom_values.value) > 0 THEN definition_custom_values.value ELSE '' END) cf_values").
    joins("LEFT JOIN custom_fields ON custom_fields.id = definition_custom_values.custom_field_id AND custom_fields.type = 'DefinitionCustomField'
           LEFT JOIN definition_sections module ON module.id = definition_custom_values.definition_section_id
           LEFT JOIN definition_sections parent_module ON module.parent_id = parent_module.id
           LEFT JOIN definitions ON definitions.id = definition_custom_values.definition_id
           INNER JOIN projects ON projects.id = definitions.project_id").
    where("definitions.id = #{product_definition_id} and parent_module.id in (#{parent_id})").
    order("module.id,custom_fields.position,definition_custom_values.id,SUBSTRING_INDEX(custom_fields.name,'|',1),SUBSTRING_INDEX(custom_fields.name,'|',-1)").
    group("SUBSTRING_INDEX(custom_fields.name,'|',1)")
  }

  def self.update_value_and_make_alter_record(value_id, value)
    cv                = DefinitionCustomValue.find(value_id)
    old_value         = cv.value
    cv.value          = value # cv.custom_field_id.to_s == DefinitionCustomField.defintion_version.id.to_s ? (value.to_s.strip.length > 0 ? value : Definition.find(cv.definition_id).auto_version) : value
    if cv.save
      if old_value.to_s != value.to_s
        dfa                     = DefinitionAlterRecord.new
        dfa.definition_id       = cv.definition_id
        dfa.record_type         = DefinitionAlterRecord::UPDATE_RECORD
        dfa.prop_key            = DefinitionCustomField.find(cv.custom_field_id).name
        dfa.user_id             = User.current.id
        dfa.old_value           = old_value
        dfa.value               = cv.value
        # dfa.definition_version  = Definition.find(cv.definition_id).product_version
        dfa.save
      end
    end
  end

  private
  def init_definiton_version
    self.value = "0.0.1" if self.custom_field_id.to_s == DefinitionCustomField.defintion_version.id.to_s
  end
end
