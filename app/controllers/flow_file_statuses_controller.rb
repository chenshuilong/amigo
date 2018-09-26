class FlowFileStatusesController < ApplicationController
  def new
    @status = FlowFileStatus.new
  end

  def create
    @status = FlowFileStatus.new(status_params)
    @status.author_id = User.current.id

    if @status.save
      render :json => {:success => 1, :message => l(:notice_successful_create)}.to_json
    else
      messages = @status.errors.full_messages.join("; ")
      render :json => {:success => 0, :message => messages}.to_json
    end
  end

  def destroy
    @status = FlowFileStatus.find(params[:id])

    respond_to do |format|
      if @status.can_delete?
        @status.destroy
        format.html do
          flash[:notice] = "删除成功！"
          redirect_back_or_default manage_flow_files_path
        end 
      else
        format.html do
          flash[:warning] = "检测到该状态已经关联到流程文档，不能删除！"
          redirect_back_or_default manage_flow_files_path
        end
      end
    end
  end

  private

  def status_params
    params.require(:flow_file_status).permit(:name)
  end
end
