class DemandsController < ApplicationController
  include Pundit

  before_filter :require_login
  before_action :find_demand, only: [:show, :edit, :update]
  before_action :find_categories, except: [:index]
  
  def index
    @category_id       = params[:category_id]
    @sub_category_id   = params[:sub_category_id]
    @status            = params[:status] 
    @created_at_start  = params[:created_at_start]
    @created_at_end    = (Date.parse(params[:created_at_end]) + 1).to_s if params[:created_at_end].present?
    
    scope = Demand.all
    scope = scope.where(category_id: @category_id)                           if @category_id.present?
    scope = scope.where(sub_category_id: @sub_category_id)                   if @sub_category_id.present?
    scope = scope.where(status: @status)                                     if @status.present?
    scope = scope.where(:created_at => @created_at_start..@created_at_end)   if @created_at_start.present?

    @limit = per_page_option
    @count = scope.count
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @demands = scope.limit(@limit).offset(@offset).reorder("created_at desc").to_a

    @demand_categories = DemandCategory.all
    @source_categories = DemandSourceCategory.all
  end

  def new
    auth :demand
    @demand = Demand.new
  end

  def create
    auth :demand
    @demand = Demand.new(demand_params)
    @demand.author_id = User.current.id
    @demand.save_attachments(params[:attachments]) if params[:attachments].present?

    if @demand.save
      respond_to do |format|
        format.html { redirect_to demands_path }
        format.api { render :text => "Saved!", :status => :ok }
      end
    else
      respond_to do |format|
        format.html { render 'new' }
        format.api { render_error }
      end
    end
  end

  def edit
    auth @demand
  end

  def update
    auth @demand
    @demand.save_attachments(params[:attachments]) if params[:attachments].present?
    @demand.init_alter

    if @demand.update(demand_params)
      @demand.generate_notes_alter_record(params[:notes]) if params[:notes].present? 
      respond_to do |format|
        format.html { redirect_to demands_path }
        format.api { render :text => "Saved!", :status => :ok }
      end
    else
      respond_to do |format|
        format.html { render 'edit' }
        format.api { render_error }
      end
    end
  end

  def show
    auth :demand 
    @notes = @demand.visible_alter_records("notes")
    @historys = @demand.visible_alter_records 
  end

  private
  def demand_params
    params.require(:demand).permit(:category_id, :sub_category_id, :description, :method, :status, :feedback_at, :related_ids, :related_notes)
  end

  def find_categories
    demand_categories = DemandCategory.active.pluck(:name, :id) 
    @demand_categories = demand_categories.present? ? demand_categories : [[]]
    source_categories = DemandSourceCategory.active.pluck(:name, :id)
    @source_categories = source_categories.present? ? source_categories : [[]]
  end

  def find_demand
    @demand = Demand.find(params[:id])
  end
end
