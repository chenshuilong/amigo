class GoogleToolsController < ApplicationController
  before_filter :require_login
  accept_api_auth :operate, :new, :create, :edit, :update, :destroy

  layout :google_tool_layout

  def index
    auth :google_tool
    @cts_ctsv_tools = GoogleTool.where(category: 10).valid_tools
    @vts_gsi_tools = GoogleTool.where(category: 20).valid_tools
    @gts_tools = GoogleTool.where(category: 30).valid_tools
  end

  def category
    auth :google_tool
    @category = params[:category] || 10

    scope = GoogleTool.where(category: @category).includes(:attachments)

    @limit = per_page_option
    @count = scope.count
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @tools = scope.limit(@limit).offset(@offset).reorder("created_at desc").to_a

    @category_text = GoogleTool::GOOGLE_TOOL_CATEGORY.key(@category.to_i).to_s
    @title = l("google_tool_category_#{@category_text}")
  end

  def operate
    auth :google_tool
    @operate_type = params[:operate_type] || "new"
    @tool = GoogleTool.find(params[:id]) if @operate_type == "edit"
    @category = params[:category] || 10
    @title = l("google_tool_category_#{GoogleTool::GOOGLE_TOOL_CATEGORY.key(@category.to_i).to_s}")
  end

  def new
    auth :google_tool
    @category = params[:category] || 10
    @tool = GoogleTool.new
    @tool.category = @category
    @title = @tool.tool_version_text
    @extra_types = @tool.get_tool_url_type
  end

  def create
    auth :google_tool
    @category = params[:category]
    @tool = GoogleTool.new(tool_params)
    @tool.category = @category
    @tool.author_id = User.current.id
    if params[:attachments].present?
      save_files = @tool.update_attachments(params[:attachments])
      @tool.save_attachments(save_files) if save_files.present?
    end

    respond_to do |format|
      if params[:attachments].blank?
        text = @tool.category.to_i == 30 ? "必须上传" : "至少上传一种类型工具！"
        message = "#{@tool.get_tool_url_type.map(&:upcase).join('/')} #{text}"
        format.api  { render :text => {:success => 0, :message => [message]}.to_json }
      elsif @tool.save
        format.api  { render :text => {:success => 1, :message => l(:option_message_suc)}.to_json }
      else
        format.api  { render :text => {:success => 0, :message => @tool.errors.full_messages}.to_json }
      end
    end
  end

  def edit
    auth :google_tool
    @tool = GoogleTool.find(params[:id])
    @title = @tool.tool_version_text
    @extra_types = @tool.get_tool_url_type 
  end

  def update
    auth :google_tool
    @tool = GoogleTool.find(params[:id])
    @tool.assign_attributes(tool_params)
    if params[:attachments].present?
      save_files = @tool.update_attachments(params[:attachments])
      @tool.save_attachments(save_files) if save_files.present?
    end

    respond_to do |format|
      if params[:attachments].blank?
        text = @tool.category.to_i == 30 ? "必须上传" : "至少上传一种类型工具！"
        message = "#{@tool.get_tool_url_type.map(&:upcase).join('/')} #{text}"
        format.api  { render :text => {:success => 0, :message => [message]}.to_json }
      elsif @tool.save
        format.api  { render :text => {:success => 1, :message => l(:option_message_suc)}.to_json }
      else
        format.api  { render :text => {:success => 0, :message => @tool.errors.full_messages}.to_json }
      end
    end
  end

  def destroy
    auth :google_tool
    @tool = GoogleTool.find(params[:id])
    if @tool.do_delete
      render :js => 'layer.msg("删除成功！");'
    else
      render :js => 'layer.msg("删除失败！");'
    end
  end

  private

  def tool_params
    params.require(:google_tool).permit(:android_version, :tool_version, :closed_at, :notes)
  end

  def google_tool_layout
    %w(new edit).include?(params[:action]) ? "faster_new" : "repo"
  end
end
