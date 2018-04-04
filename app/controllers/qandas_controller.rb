class QandasController <  ApplicationController
  before_filter :require_login
  before_action :require_admin, :except => [:index, :show]

  def index
    search = params[:q]
    if search.present?
      scope = $db.slave { Qanda.where("subject like ? OR tag like ?", "%#{search}%", "%#{search}%") }
    else
      scope = $db.slave { Qanda.all }
    end
    @pages = (params['page'] || 1).to_i
    @limit = (params['per_page'] || 15).to_i
    @qanda_count = scope.count
    @qanda_pages = Paginator.new @qanda_count, @limit, @pages
    @qandas = $db.slave { scope.order("created_at desc").limit(@limit).offset(@limit*(@pages-1)) }
  end

  def new
    @qanda = Qanda.new
  end

  def create
    @qanda = Qanda.new(qanda_params)
    @qanda.tag = params[:qanda][:tag].reject(&:blank?).join(",")
    if @qanda.save
      redirect_to @qanda
    else
      render 'new'
    end
  end

  def show
    @qanda = Qanda.find(params[:id])
    @qanda.add_view_count!
  end

  def edit
    @qanda = Qanda.find(params[:id])
  end

  def update
    @qanda = Qanda.find(params[:id])
    @qanda.update_attributes(qanda_params)
    @qanda.tag = params[:qanda][:tag].reject(&:blank?).join(",")
    if @qanda.save
      redirect_to @qanda
    else
      render 'edit'
    end
  end

  def destroy
    Qanda.find(params[:id]).destroy
    redirect_to qandas_path
  end

  private

  def qanda_params
    params.require(:qanda).permit(:subject, :content)
  end

end

