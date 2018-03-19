class MokuaisController < ApplicationController
  before_filter :require_admin, except: [:new, :create, :list, :edit_batch, :sync_batch, :history]

  layout :mokuais_layout

  def index
    @pages = (params['page'] || 1).to_i
    @limit = (params['per_page'] || 50).to_i

    @category = params[:category]
    @reason   = params[:reason]
    @name     = params[:name]

    scope = Mokuai.all
    scope = scope.where(:category => @category) if @category.present?
    scope = scope.where("reason LIKE '%#{@reason}%'") if @reason.present?
    scope = scope.where("name LIKE '%#{@name}%'") if @name.present?

    @mokuai_count = scope.count
    @mokuai_pages = Paginator.new @mokuai_count, @limit, @pages
    @mokuais = scope.limit(@limit).offset(@limit*(@pages-1))

  end

  def new
    @from = params[:from]
    @mokuai = Mokuai.new
  end

  def create
    if params[:from].present?
      @mokuai = Mokuai.new(mokuai_update_params)
      if @mokuai.save
        @mokuai.generate_alter_record
        result = {:success => 1, :messages => "Success !"}
      else
        messages = @mokuai.errors.messages
        text = "操作失败!<br/>"
        if messages.present?
          arr = []
          messages.each do |k, v|
            arr << l("field_mokuai_#{k.to_s}") + v[0]
          end
          text = text + arr.join("<br/>")
        end
        result = {:success => 0, :messages => text }
      end
      render json: result.to_json
    else
      mokuai = Mokuai.import(params[:file])
      # render :text => mokuai
      flash[:notice] = "导入成功！"
      redirect_to :back
    end
  end

  def edit
    @mokuai = Mokuai.find(params[:id])
    respond_to do |format|
      format.js
    end
  end

  def update
    Mokuai.find(params[:id]).update_attributes(mokuai_update_params)
    @mokuai = Mokuai.find_by_id(params[:id])
    respond_to { |format| format.js }
  end

  def destroy
    @mokuai_id = params[:id]
    Mokuai.find(@mokuai_id).destroy
    respond_to do |format|
      format.js
    end
  end

  def list
    auth :mokuai
    reason = params[:reason]
    name   = params[:name]

    scope = Mokuai.where(category: 1)

    scope = scope.where("reason LIKE '%#{reason}%'") if reason.present?
    scope = scope.where("name LIKE '%#{name}%'")     if name.present?

    @limit = per_page_option
    @count = scope.count
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset

    @mokuais = scope.limit(@limit).offset(@offset).to_a
  end

  def edit_batch
    @mokuai = Mokuai.find(params[:id])
    respond_to { |format| format.js }
  end

  def sync_batch
    @mokuai = Mokuai.find(params[:id])
    if params[:project_ids].present? && params[:users].present? && (params[:users][:tfde].present? || params[:users][:ownner].present?)
      @projects = Project.where(id: params[:project_ids])
      result = @projects.sync_mokuai_owner_batch(@mokuai, params[:users])
    else
      result = {:success => 0, :messages => "操作失败! 需同步项目范围必填, 且TFDE、OWNER至少选择一个"}
    end
    render json: result.to_json
  end

  def history
    @mokuai = Mokuai.find(params[:id])
    @records = @mokuai.alter_records
    respond_to { |format| format.js }
  end

  private

  def mokuai_update_params
    params.require(:mokuai).permit(:category, :reason, :name, :description, :package_name)
  end

  def mokuais_layout
    %w(list).include?(params[:action]) ? "repo" : "admin" 
  end

end
