class SignaturesController < ApplicationController
  before_filter :require_login
  before_action :find_signature, only: [:show, :change]

  def index
    auth :signature
  	@name   = params[:name]
  	@status = params[:status]
  	@author = params[:author]

    scope = Signature.includes(:author)

    scope = scope.where("name LIKE '%#{@name}%'") if @name.present?
    scope = scope.where(status: @status) if @status.present?
    scope = scope.where(author_id: @author) if @author.present?

    @limit = per_page_option
    @count = scope.count
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @signs = scope.limit(@limit).offset(@offset).reorder("created_at desc").to_a
  end

  def new
    auth :signature
    @sign = Signature.new
  end

  def create
    auth :signature
    @sign = Signature.new(signature_params)
    @sign.status = 1
    @sign.category = 1
    @sign.author_id = User.current.id
    @sign.name = params[:attachments].values[0]["filename"] if params[:attachments].present?
    @sign.save_attachments(params[:attachments])
    respond_to do |format|
      if params[:attachments].blank?
        format.html do
          @alert = "请选择待签名应用"
          render :action => 'new'
        end
      elsif @sign.save
        format.html do
          flash[:notice] = l(:notice_successful_update)
          redirect_back_or_default signatures_path
        end
      else          
        format.html { render :action => 'new' }
      end
    end
  end

  def show
    auth :signature
  end

    # For Jenkins to update version or fixed issues etc.
  def change
    if params[:token].in? [Token::SCM_TOKEN]
      has = -> (key) { params.has_key?(key) }
      if has.(:sign) # update jenkins return infos
        saved = @sign.update(allow_jenkins_update_params)
      else
        saved = false
      end
      respond_to do |format|
        if saved
          format.api{ render :text => "Saved!", :status => :ok }
        else
          format.api{ render_error }
        end
      end
    else
      render_error :status => 422, :message => "Invalid authenticity token."
    end
  end

  private
  def signature_params
    params.require(:signature).permit(:key_name, :notes)
  end

  def allow_jenkins_update_params
    jenkins_params = params.require(:sign).permit(:status, :upload_url, :download_url, :infos)
    jenkins_params[:due_at] = Time.now if jenkins_params[:status].present?
    return jenkins_params
  end

  def find_signature
    @sign = Signature.find(params[:id])
  end
end
