module DefinitionsHelper
  def main_module
    DefinitionSection.main_module || []
  end

  def main_module_market_positioning
    main_module.find_by(:name => DefinitionSection::MENU_MINGMING)
  end

  def main_module_product_definition
    main_module.find_by(:name => DefinitionSection::MENU_CHANPING)
  end

  def sub_module(product_definition_id, parent_id)
    DefinitionCustomValue.definition_custom_fields(product_definition_id, parent_id)
  end

  def sub_module_group(product_definition_id, parent_id)
    sub_module(product_definition_id, parent_id).group_by(&:module_name)
  end

  def sub_custom_field_group(product_definition_id, parent_id)
    DefinitionCustomValue.definition_custom_fields_group(product_definition_id, parent_id).group_by(&:module_name)
  end

  def choose_product_custom_feilds
    DefinitionCustomField.all.map { |dcf| [dcf.name, dcf.id] } - @definition.definition_custom_values.map { |cf| [DefinitionCustomField.find(cf.custom_field_id).name, cf.custom_field_id] }
  end

  def choose_custom_feilds(product_definition_id)
    DefinitionCustomField.all.map { |cf| [cf.name, cf.id] } -
        sub_module(product_definition_id, main_module.map { |main| main.id }.join(',')).map { |sub| [sub.name, sub.cf_id] }
  end

  def choose_module_feilds
    DefinitionCustomField.all.map { |cf| [cf.name, cf.id] } - DefinitionSectionsCustomFields.fields.map { |mf| [mf.name, mf.custom_field_id] }
  end

  def choose_modules
    @definition_module.map { |v| [v.name, v.id] }
  end

  def allow_to_view_definition?
    User.current.allowed_to?(:view_definition, @project, :global => true) || User.current.admin?
  end

  def allow_to_manage_definition?
    allow_to_manage_product_definition? || allow_to_manage_definition_module? || allow_to_manage_definition_custom_field? || allow_to_manage_definition_module_field? || allow_to_manage_compare_model?
  end

  def allow_to_new_product_definition?
    User.current.allowed_to?(:new_product_definition, @project, :global => true) || User.current.admin?
  end

  def allow_to_copy_product_definition?
    User.current.allowed_to?(:copy_product_definition, @project, :global => true) || User.current.admin?
  end

  def allow_to_manage_product_definition?
    User.current.allowed_to?(:manage_product_definition, @project, :global => true) || User.current.admin?
  end

  def allow_to_manage_definition_module?
    User.current.allowed_to?(:manage_definition_module, @project, :global => true) || User.current.admin?
  end

  def allow_to_manage_definition_custom_field?
    User.current.allowed_to?(:manage_definition_custom_field, @project, :global => true) || User.current.admin?
  end

  def allow_to_manage_definition_module_field?
    User.current.allowed_to?(:manage_definition_module_field, @project, :global => true) || User.current.admin?
  end

  def allow_to_manage_compare_model?
    User.current.allowed_to?(:manage_compare_model, @project, :global => true) || User.current.admin?
  end

  def to_user(user_id)
    link_to_user(User.find(user_id) || User.current)
  end

  def field_format_for_select
    options_for_select([["字符串", "string"], ["单选", "list"], ["日期", "date"]])
  end

  def subsection_for_select
    options_for_select([["不细分", ""], ["产品定义细分", "|规格,|描述,|性能要求,|对标机型"]])
  end

  def field_value_by_id(dfv_id)
    parent_id = DefinitionSection.find(DefinitionCustomValue.find(dfv_id).definition_module_id).parent_id
    DefinitionCustomValue.definition_custom_fields(DefinitionCustomValue.find(dfv_id).product_definition_id, parent_id).where("custom_fields.id = #{DefinitionCustomValue.find(dfv_id).custom_field_id}")
  end

  def sort_field_by_group(cf_names, cf_ids, dfv_ids, formats, values)
    module_fields = []
    cf_names.to_s.split(',').each_with_index { |name, idx|
      md = {:id => dfv_ids.to_s.split(',')[idx] || "-", :cf_id => cf_ids.to_s.split(',')[idx] || "-", :field_format => formats.to_s.split(',')[idx] || "-", :value => values.to_s.split(',')[idx] || ""}
      case name.to_s
        when "规格" then
          module_fields[0] = md
        when "描述" then
          module_fields[1] = md
        when "性能要求" then
          module_fields[2] = md
        when "对标机型" then
          module_fields[3] = md
      end
    }
    module_fields
  end

  def edit_by_field_format(field)
    case field[:field_format]
      when "string" then
        if field[:value].to_s.include?("\n")
          text_area_tag "fields[cf_#{field[:id]}]", "#{field[:value]}", :rows => 5, :class => 'wiki-edit', style: 'width:100%'
        else
          text_area_tag "fields[cf_#{field[:id]}]", "#{field[:value]}", class: 'form-control'
        end
      when "date" then
        text_field_tag "fields[cf_#{field[:id]}]", "#{field[:value]}", class: 'form-control'
      when "list" then
        select_tag "fields[cf_#{field[:id]}]", options_for_select(DefinitionCustomField.find(field[:cf_id]).possible_values.map { |v| [v, v] },selected: "#{field[:value]}"), {class: 'form-control', value: "#{field[:value]}"}
      else
        text_area_tag "fields[cf_#{field[:id]}]", "#{field[:value]}"
    end
  end

  def edit_by_compare_model(field)
    select_tag "fields[cf_#{field[:id]}]", options_for_select(CompetitiveGoods.all.map { |v| [v.name, v.name] }), :multiple => :multiple, class: 'value form-control select-multiple', style: 'width:100%'
  end

  def edit_custom_value(definition_id, field_id, field_type, cf_id)
    field_type = convert_field_type field_type
    field_values = custom_field_possible_values(cf_id)

    javascript_tag(
        <<~STRING
          $('#fields_cf_#{field_id}').editable({
                 url: '/product_definition/edit_custom_value?id=#{field_id}',
                 type: '#{field_type}',
                 pk: 1,
                 name: 'fields_cf_#{field_id}',
                 title: '请输入值'
          });
        STRING
    )
  end

  def to_record_type(type)
    case type
      when DefinitionAlterRecord::NEW_RECORD then
        "新增"
      when DefinitionAlterRecord::UPDATE_RECORD then
        "修改"
      when DefinitionAlterRecord::DELETE_RECORD then
        "删除"
      else
        ""
    end
  end

  def copy_type_description
    %(
      <ul>
        <li>完全复制<br>复制所选项目下的所有字段及相应的值</li>
        <li>仅复制字段<br>仅复制所选项目下的所有字段,不复制相应的值</li>
      </ul>
      <p style='color:red;'>注:被复制的项目下必须存在字段.</p>
     )
  end

  def table_subsection_heads
    ["细分", "支持/不支持/规格", "描述", "性能要求", "对标机型"].map { |h| "<td><b>#{h}</b></td>" }.join('').html_safe
  end

  private
  def convert_field_type(field_type)
    case field_type when "string" then "textarea" when "list" then "textarea" else field_type end
  end

  def custom_field_possible_values(custom_field)
    values = DefinitionCustomField.find(custom_field).possible_values
    values.is_a?(Array) ? values.map { |v| {"value": v, "text": v} } : values
  end
end
