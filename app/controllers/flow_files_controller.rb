class FlowFilesController < ApplicationController
  before_filter :require_login
  before_action :get_status_and_type, except: [:index, :show, :destroy, :flow_file_attachments, :manage]

  def index
    auth :flow_file
    @author = params[:author_id]
    @type = params[:file_type_id]
    @name = params[:name]
    @status = params[:file_status_id]

    scope = FlowFile.includes(:author)
 
    scope = scope.where(author_id: @author) if @author.present?
    scope = scope.where(file_type_id: @type) if @type.present?
    scope = scope.where("name like '%#{@name}%'") if @name.present?
    scope = scope.where(file_status_id: @status) if @status.present?

    @limit = per_page_option
    @count = scope.count
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @files = scope.limit(@limit).offset(@offset).reorder("created_at desc").to_a

    @types = FlowFileType.pluck(:name, :id)
    @statuses = FlowFileStatus.pluck(:name, :id)
  end

  def new
    auth :flow_file
    @file = FlowFile.new
    @no = FlowFile.get_no
  end

  def create
    auth :flow_file
    @file = FlowFile.new
    @file.author_id = User.current.id
    saved = @file.do_save(flow_file_params, params[:attachments], params[:flow_file_attachments])
    respond_to do |format|
      if saved
        format.html do
          flash[:notice] = l(:notice_successful_create)
          redirect_back_or_default flow_files_path
        end
      else
        @attachments = @file.attachments.where(extra_type: "flow_file", deleted: false) + @file.saved_attachments
        @ffa_ids = params[:flow_file_attachments]
        format.html { render :action => 'new' }
      end
    end
  end

  def edit
    auth :flow_file
    @file = FlowFile.find(params[:id])
    @attachments = @file.attachments.where(extra_type: "flow_file", deleted: false)
    @no = FlowFile.get_no(@file.id, @file.file_type_id)
  end

  def update
    auth :flow_file
    @file = FlowFile.find(params[:id])
    saved = @file.do_save(flow_file_params, params[:attachments], params[:flow_file_attachments])

    respond_to do |format|
      if saved
        format.html do
          flash[:notice] = l(:notice_successful_update)
          redirect_back_or_default flow_files_path
        end
      else
        @attachments = @file.attachments.where(extra_type: "flow_file", deleted: false) + @file.saved_attachments
        @ffa_ids = params[:flow_file_attachments]
        format.html { render :action => 'edit' }
      end
    end
  end

  def show
    auth :flow_file
    @file = FlowFile.find(params[:id])

    @records = @file.alter_records.reorder("created_at desc")
  end

  def flow_file_attachments
    @id = params[:id]
    @name = params[:name]

    abandon_status = FlowFileStatus.where(name: "废弃").pluck(:id)
    scope = FlowFile.where.not(file_status_id: abandon_status)
    scope = scope.file_attachments(@id)
    scope = scope.where("flow_files.name like '%#{@name}%' or attachments.filename like '%#{@name}%'") if @name.present?
    page     = params[:page] || 1
    limit    = 20
    offset   = (page.to_i - 1) * limit
    attas = scope.limit(limit).offset(offset)

    options = []
    attas.each do |atta|
      optgroups = []
      atta.attachment_list.split(",").each_slice(2) do |a|
        optgroups << {'id': a[1], 'text': a[0]}
      end
      optgroup = {'text': atta.name, 'children': optgroups}
      options << optgroup
    end

    render :json => {options: options}.to_json
  end

  def manage
    auth :flow_file
    @types = FlowFileType.all
    @statuses = FlowFileStatus.all
  end

  def destroy
    auth :flow_file
    @file = FlowFile.find(params[:id])
    @file.do_abandon
    respond_to do |format|
      format.html do
        flash[:notice] = "废弃成功!"
        redirect_back_or_default flow_files_path
      end
    end    
  end

  def get_no
    @file_id = params[:id]
    @file_type_id = params[:file_type_id]
    no = FlowFile.get_no(@file_id, @file_type_id)
    render :json => {no: no}.to_json
  end

  private
  def flow_file_params
    params.require(:flow_file).permit(:name, :version, :file_type_id, :file_status_id, :use)
  end

  def attachment_params
    params.require(:attachments)
  end

  def get_status_and_type
    @statuses = FlowFileStatus.where(editable: true).pluck(:name, :id)
    @types = FlowFileType.pluck(:name, :id)
  end
end
