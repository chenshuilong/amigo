class TemplatesController < ApplicationController
  before_filter :require_login
  before_action :find_temp, only: [:edit, :update, :destroy]
  layout 'admin'

  def index
    @project_nones = Template.where(role_type: 2).roles
    @project_groups = Template.where(role_type: 3).roles_by_object
    @app_nones = Template.where(role_type: 1).roles
  end

  def new
    @type = params[:type] || 'project_none'
    @temp = Template.new
    @temp.role_type = Template::TEMPLATE_ROLE_TYPE[@type.to_sym]

    @roles, @groups = @temp.valid_roles_and_groups
  end

  def create
    @temp = Template.new(temp_params)
    @temp.author_id = User.current.id
    respond_to do |format|
      if @temp.save
        format.html do
          flash[:notice] = l(:notice_successful_create)
          redirect_back_or_default templates_path
        end
      else
        format.html { render :action => 'new' }
      end
    end
  end

  def edit
    @type = Template::TEMPLATE_ROLE_TYPE.key(@temp.role_type).to_s

    @roles, @groups = @temp.valid_roles_and_groups
  end

  def update
    @temp.update_attributes(temp_params)
    if @temp.save
      redirect_to templates_path
    else
      render 'edit'
    end
  end

  def destroy
    @temp.destroy
    redirect_to templates_path
  end

  private
  def temp_params
    params.require(:template).permit(:role_id, :object_id, :object_type, :role_type)
  end

  def find_temp
    @temp = Template.find(params[:id])
  end
end
