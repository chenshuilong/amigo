class FlowFileTypesController < ApplicationController
  def new
    @type = FlowFileType.new
  end

  def create
    @type = FlowFileType.new(type_params)
    @type.author_id = User.current.id

    if @type.save
      render :json => {:success => 1, :message => l(:notice_successful_create)}.to_json
    else
      messages = @type.errors.full_messages.join("; ")
      render :json => {:success => 0, :message => messages}.to_json
    end
  end

  def destroy
  	@type = FlowFileType.find(params[:id])
    respond_to do |format|
      if @type.can_delete?
        @type.destroy
        format.html do
          flash[:notice] = "删除成功！"
          redirect_back_or_default manage_flow_files_path
        end 
      else
        format.html do
          flash[:warning] = "检测到该类型已经关联到流程文档，不能删除！"
          redirect_back_or_default manage_flow_files_path
        end
      end
    end
  end

  private 
  def type_params
    new_params = params.require(:flow_file_type).permit(:name, :code)
    new_params[:code] = new_params[:code].squish if new_params[:code].present?
    return new_params
  end
end
