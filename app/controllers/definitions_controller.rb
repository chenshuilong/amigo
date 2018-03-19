class DefinitionsController < ApplicationController

  helper :attachments

  layout 'admin'
  before_action :find_project_by_project_id, :only => [:new, :copy, :module_show, :edit_custom_value]
  before_action :require_login

  def index
    respond_to do |format|
      format.html {
        @project            = Project.find_by_identifier(params[:project_id])
        @edit_all           = (params[:edit_all] || "false") == "true"
        @definition         = @project.definition
        @main_module        = DefinitionSection.main_module || []
        @definition_module  = DefinitionSection.second_level_module
        @records            = @definition ? @definition.definition_alter_records : []
      }
      format.api {
        render_api_ok
      }
    end
  end

  def new
    @definition         = @project.definition
    if @definition.definition_custom_values.blank?
      DefinitionSectionsCustomFields.all.each do |cf|
        @definition.definition_custom_values << DefinitionCustomValue.new({:definition_section_id => cf.definition_section_id,:custom_field_id => cf.custom_field_id}) if @definition.definition_custom_values.find_by_custom_field_id(cf.custom_field_id).blank?
      end
    end

    render :text => {:success => 1, :message => "创建成功!"}.to_json
  rescue => e
    render :text => {:success => 0, :message => e.to_s}.to_json
  end

  def create
    @definition = Definition.new
    @definition.project_id = @project.id
    @definition.attributes = product_definition_params
    @definition.save_attachments(params[:attachments]) if params[:attachments]

    if @definition.save
      render_attachment_warning_if_needed(@definition)
      flash[:notice] = l(:notice_successful_create)
      redirect_to project_product_definition_path(@definition)
    else
      render :action => 'new'
    end
  end

  def show
    @definition = @project.definition.find_by(:id => params[:id])
  end

  def edit; end

  def copy
    DefinitionCustomValue.transaction do
      if copy_definition_params[:copy_project_id].present? && copy_definition_params[:copy_type].present?
        Project.find(copy_definition_params[:copy_project_id]).definition.definition_custom_values.each do |dcv|
          if copy_definition_params[:copy_type].to_i == 1
            if @project.definition.definition_custom_values.find_by_custom_field_id(dcv.custom_field_id).blank?
              @project.definition.definition_custom_values << DefinitionCustomValue.new({:definition_section_id => dcv.definition_section_id, :custom_field_id => dcv.custom_field_id, :value => dcv.value})
            else
              dfv = @project.definition.definition_custom_values.find_by_custom_field_id(dcv.custom_field_id)
              dfv.value = dcv.value
              dfv.save
            end
          else
            @project.definition.definition_custom_values << DefinitionCustomValue.new({:definition_section_id => dcv.definition_section_id, :custom_field_id => dcv.custom_field_id}) if @project.definition.definition_custom_values.find_by_custom_field_id(dcv.custom_field_id).blank?
          end
        end
      end
    end

    respond_to do |format|
      format.api { render_api_ok }
    end
  end

  def definition_custom_values
    values = DefinitionCustomValue.definition_custom_fields(params[:definition_id], DefinitionSection.main_module.map{|m| m.id}.join(','))

    render_text_to_json({:rows => values})
  end

  def definition_modules
    modules = DefinitionSection.format_modules

    render_text_to_json({:rows => modules})
  end

  def definition_custom_fields
    fields = DefinitionCustomField.all

    render_text_to_json({:rows => fields})
  end

  def definition_module_fields
    fields = DefinitionSectionsCustomFields.configrated
    fields = fields.where("#{DefinitionSectionsCustomFields.table_name}.definition_section_id = #{params[:module_id]}") if params[:module_id]

    render_text_to_json({:rows => fields})
  end

  def definition_compare_model
    models = CompetitiveGoods.select("users.firstname author,competitive_goods.*").joins(:user)

    render_text_to_json({:rows => models})
  end

  def hide_definition_module
    dm         = DefinitionSection.find(params[:module_id])
    dm.display = params[:display]
    dm.save

    render_text_to_json({:success => 1, :rows => dm})
  end

  def create_custom_field
    if create_custom_field_params["field_subsection"].empty?
      raise "请勿重复创建!" if DefinitionCustomField.find_by_name(create_custom_field_params[:name])
      custom_field_params = create_custom_field_params
      custom_field_params.delete "field_subsection"
      DefinitionCustomField.create(custom_field_params)
    else
      create_custom_field_params["field_subsection"].split(',').each do |f_name|
        field_name = create_custom_field_params[:name] + f_name
        raise "请勿重复创建!" if DefinitionCustomField.find_by_name(field_name)
        custom_field_params = create_custom_field_params
        custom_field_params["name"] = field_name
        custom_field_params.delete "field_subsection"
        DefinitionCustomField.create(custom_field_params)
      end
    end

    render :text => {:success => 1, :message => "创建成功!"}.to_json
  rescue => e
    render :text => {:success => 0, :message => e.to_s}.to_json
  end

  def edit_custom_field
    possible_values = params["data"]["custom_fields"]["possible_values"]
    field_format    = params["data"]["custom_fields"]["field_format"]
    params["data"]["fids"].each do |fid|
      dcf                 = DefinitionCustomField.find(fid)
      dcf.possible_values = possible_values
      ActiveRecord::Base.connection.execute("UPDATE custom_fields SET field_format = '#{field_format}' WHERE id = #{dcf.id}") if dcf.save
    end

    render :text => {:success => 1, :message => "修改成功!"}.to_json
  rescue => e
    render :text => {:success => 0, :message => e.to_s}.to_json
  end

  def create_definition_module
    raise "请勿重复创建!" if DefinitionSection.find_by_name(create_definition_module_params[:name])
    dfm_params             = create_definition_module_params
    dfm_params[:author_id] = User.current.id
    DefinitionSection.create(dfm_params)

    render :text => {:success => 1, :message => "创建成功!"}.to_json
  rescue => e
    render :text => {:success => 0, :message => e.to_s}.to_json
  end

  def edit_definition_module
  end

  def create_module_field
    raise "请勿重复创建!" if DefinitionSectionsCustomFields.find_by_custom_field_id(create_module_field_params[:custom_field_id])
    create_module_field_params[:custom_field_id].to_s.split(',').each do |cf_id|
      mf = DefinitionSectionsCustomFields.new
      mf.custom_field_id = cf_id
      mf.definition_section_id = create_module_field_params[:definition_module_id]
      mf.save
    end

    render_text_to_json({:success => 1, :message => "创建成功!"})
  end

  def edit_module_field
  end

  def delete_module_field
    DefinitionSectionsCustomFields.find(params[:id]).destroy

    render_text_to_json({:success => 1, :message => "删除成功!"})
  end

  def create_custom_value
    product_definition_id = create_custom_value_params[:product_definition_id]
    definition_module_id  = create_custom_value_params[:definition_module_id]

    raise "请勿重复创建!" if DefinitionCustomValue.find_by_definition_id_and_custom_field_id(create_custom_value_params[:product_definition_id], create_custom_value_params[:custom_field_id])

    if DefinitionSection.find(definition_module_id)
      create_custom_value_params[:custom_field_id].to_s.split(',').each do |cf_id|
        if DefinitionCustomField.find(cf_id)
          dcf                       = DefinitionCustomValue.new
          dcf.definition_id         = product_definition_id
          dcf.definition_section_id = definition_module_id
          dcf.custom_field_id       = cf_id

          record                = DefinitionAlterRecord.new
          record.definition_id  = product_definition_id
          record.record_type    = DefinitionAlterRecord::NEW_RECORD
          record.user_id        = User.current.id
          record.prop_key       = DefinitionCustomField.find(cf_id).name
          record.save if dcf.save
        end
      end
    end

    render_text_to_json({:success => 1, :message => "创建成功!"})
  end

  def edit_custom_value
    # batch edit definitions custom value
    @definition = @project.definition
    if params[:fields]
      fields = params[:fields].is_a?(Hash) ? params[:fields] : JSON.parse(params[:fields])
      fields = handle_params fields
      fields.each { |field, field_value|
        DefinitionCustomValue.update_value_and_make_alter_record(field.to_s.split('_')[1], field_value)
      }

      if params[:attachments]
        @definition.save_attachments(params[:attachments])
        @definition.save
      end
      render_attachment_warning_if_needed(@definition)
      flash[:notice] = "修改成功！"
      redirect_to_project_definition @project
    else
      DefinitionCustomValue.update_value_and_make_alter_record(params["id"], params["value"])

      render_text_to_json({:success => 1, :message => "修改成功!"})
    end
  end

  def delete_custom_value
    dcv = DefinitionCustomValue.find(params[:id])

    record                = DefinitionAlterRecord.new
    record.definition_id  = dcv.definition_id
    record.record_type    = DefinitionAlterRecord::DELETE_RECORD
    record.user_id        = User.current.id
    record.prop_key       = DefinitionCustomField.find(dcv.custom_field_id).name
    dcv.destroy if record.save

    render_text_to_json({:success => 1, :message => "删除成功!"})
  end

  def create_compare_model
    raise "请勿重复创建!" if CompetitiveGoods.find_by_name(create_compare_model_params[:name])
    CompetitiveGoods.create(create_compare_model_params)

    render_text_to_json({:success => 1, :message => "创建成功!"})
  end

  def delete_compare_model
    CompetitiveGoods.find(params[:id]).destroy

    render_text_to_json({:success => 1, :message => "删除成功!"})
  end

  def module_show
    @edit_all           = (params[:edit_all] || "false") == "true"
    @definition         = @project.definition
    @main_module        = DefinitionSection.main_module || []
    @definition_module  = DefinitionSection.second_level_module
    @module             = DefinitionSection.find(params[:id])
    @records            = @definition ? @definition.definition_alter_records : []
  end

  private

  def find_project_by_project_id
    @project = Project.find(params[:project_id])

  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def create_custom_value_params
    params.require(:product).permit(:definition_module_id, :custom_field_id, :product_definition_id)
  end

  def create_custom_field_params
    params.require(:custom_fields).permit(:name, :possible_values, :field_format, :field_subsection)
  end

  def create_definition_module_params
    params.require(:definition_modules).permit(:name, :parent_id)
  end

  def create_module_field_params
    params.require(:module_fields).permit(:definition_module_id, :custom_field_id)
  end

  def create_compare_model_params
    params.require(:compare_models).permit(:name, :user_id)
  end

  def copy_definition_params
    params.require(:definitions).permit(:copy_project_id, :copy_type)
  end

  def render_text_to_json(opt = {})
    render :text => opt.to_json
  rescue => e
    render :text => {:success => 0, :message => e.to_s}.to_json
  end

  def redirect_to_project_definition(project)
    redirect_to "/projects/#{project.identifier}/definitions"
  end

  def handle_params(fields)
    fields.delete "authenticity_token"
    fields.delete "utf8"
    fields.delete "attachments"

    product_definition_version = fields[("cf_" + DefinitionCustomField.defintion_version.id.to_s).to_sym]
    product_definition_version = product_definition_version ? product_definition_version : @definition.auto_version
    fields
  end
end
