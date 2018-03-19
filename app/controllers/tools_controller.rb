class ToolsController < ApplicationController
  before_filter :require_login
  accept_api_auth :operate, :new, :create, :edit, :update, :destroy

  layout :tool_layout

  def index
    auth :tool
    @category = params[:category] || 10

    scope = Tool.includes(:provider, :attachments)

    @limit = per_page_option
    @count = scope.count
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @tools = scope.limit(@limit).offset(@offset).reorder("created_at desc").to_a   
  end

  def operate
    auth :tool
    @operate_type = params[:operate_type] || "new"
    @tool = Tool.find(params[:id]) if @operate_type == "edit"
  end

  def new
    auth :tool
    @tool = Tool.new
    @tool.category = 1
  end

  def create
    auth :tool
    @tool = Tool.new(tool_params)
    @tool.author_id = User.current.id
    @tool.category = 1

    if params[:attachments].present?
      %w(tool_note tool_url).each do |item|
        @tool.save_attachments(params[:attachments][item.to_sym]) if params[:attachments][item.to_sym].present?
      end
    end
    
    respond_to do |format|
      if @tool.save
        format.api  { render :text => {:success => 1, :message => l(:option_message_suc)}.to_json }
      else
        format.api  { render :text => {:success => 0, :message => @tool.errors.full_messages}.to_json }
      end
    end
  end

  def edit
    auth :tool
    @tool = Tool.find(params[:id])
  end

  def update
    auth :tool
    @tool = Tool.find(params[:id])
    @tool.assign_attributes(tool_params)

    if params[:attachments].present?
      %w(tool_note tool_url).each do |item|
        @tool.save_attachments(params[:attachments][item.to_sym]) if params[:attachments][item.to_sym].present?
      end
    end

    respond_to do |format|
      if @tool.save
        format.api  { render :text => {:success => 1, :message => l(:option_message_suc)}.to_json }
      else
        format.api  { render :text => {:success => 0, :message => @tool.errors.full_messages}.to_json }
      end
    end
  end

  def destroy
    auth :tool
    @tool = Tool.find(params[:id])
    if @tool.do_delete
      render :js => 'layer.msg("删除成功！");'
    else
      render :js => 'layer.msg("删除失败！");'
    end
  end

  private
  def tool_params
    params.require(:tool).permit(:name, :description, :provider_id)
  end

  def tool_layout
    %w(new edit).include?(params[:action]) ? "faster_new" : "repo"
  end
end
