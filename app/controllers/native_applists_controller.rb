class NativeApplistsController < ApplicationController
  before_filter :require_login
  before_action :find_apk_base_categories, :only => [:new, :create, :edit, :update]
  before_action :find_app, only: [:edit, :update, :show, :destroy]

  layout "admin"

  def index
    auth :native_applist
    @limit = per_page_option
    @apps = ApkBase.where(app_category: 10).reorder("created_at desc")
  end

  def new
    auth :native_applist
    @app = ApkBase.new
    @app.developer = "Google"
  end

  def create
    auth :native_applist

    exist_apk = ApkBase.find_by(name: app_params[:name])
    if exist_apk.present? && exist_apk.app_category.present?
      respond_to do |format|
        format.html  do
          flash[:error] = "#{exist_apk.name.to_s} 已经存在，请重新命名新增原生应用APK名称!" 
          redirect_back_or_default native_applists_path
        end
      end
    else
      @app = ApkBase.new
      @app.app_category = 10
      @app.os_category = 1
      @app.author_id = User.current.id  
 
      result = @app.do_save('add', app_params)

      respond_to do |format|
        if result[:saved]
          exist_apk.destroy if exist_apk.present? && exist_apk.app_category.blank?
          format.html do
            flash[:notice] = l(:notice_successful_create)
            url = params[:continue].present? ? new_native_applist_path : native_applists_path
            redirect_back_or_default url
          end
        else
          format.html { render :action => 'new' }
        end
      end
    end
  end

  def edit
    auth :native_applist
    if @app.tasks.where(status: 24).count != 0
      flash[:error] = "#{@app.name}处于评审状态，不能进行修改！"
      redirect_back_or_default native_applists_path
    end
  end

  def update
    auth :native_applist
    if @app.tasks.where(status: 24).count != 0
      flash[:error] = "#{@app.name}处于评审状态，不能进行修改！"
      redirect_back_or_default native_applists_path
    else
      result = @app.do_save('modify', app_params)
      if result[:saved]
        respond_to do |format|
          format.html { redirect_to native_applists_path }
        end
      else
        respond_to do |format|
          format.html { render 'edit' }
        end
      end
    end
  end

  def show
    auth :native_applist
  end

  def history
    auth :native_applist
    @limit = per_page_option
    scope = AlterRecordDetail.native_applist_details
    @count = scope.count
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @records = scope.limit(@limit).offset(@offset).to_a
  end

  def destroy
    auth :native_applist
    @app.update(deleted: true, deleted_at: Time.now)
    @app.generate_alter_record("delete")
    redirect_to native_applists_path
  end

  private
  def app_params
    attr_params = params.require(:apk_base).permit(:name, :cn_name, :desktop_name, :cn_description, :developer, :package_name, :removable, :category_id, :notes, :android_platform)
    attr_params[:name] = attr_params[:name].squish if attr_params[:name].present?
    return attr_params
  end

  def find_app
    @app = ApkBase.find(params[:id])
  end

  def find_apk_base_categories
    @categories = ApkBaseCategory.active
  end
end
