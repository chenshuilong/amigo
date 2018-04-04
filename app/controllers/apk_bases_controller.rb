class ApkBasesController < ApplicationController
 before_filter :require_login
  before_action :find_project_by_project_id, :only => [:apks, :new, :create, :edit, :update, :destroy]
  before_action :find_apk_base_categories, :only => [:new, :create, :edit, :update]
  before_action :find_apk_base, :only => [:edit, :update, :destroy]
  before_filter :authorize, :except => [:index, :history, :search]

  layout :apk_bases_layout

  def index
    auth :apk_base
    @removable    = params[:removable]
    @name         = params[:name]
    @category_id  = params[:category_id]
    @app_category = params[:app_category]
    @project_id   = params[:project_id]
    @package_name = params[:package_name]
    @type         = params[:type]
    @integrated   = params[:integrated]
    @android_platform = params[:android_platform]

    @limit = per_page_option

    scope = $db.slave { ApkBase.search }
    scope = $db.slave { scope.where(android_platform: 2) } if @type.present?
    scope = $db.slave { scope.where(removable: (@removable == 'none' ? nil : @removable)) } if @removable.present?
    scope = $db.slave { scope.where("apk_bases.name LIKE '%#{@name}%'") } if @name.present?
    scope = $db.slave { scope.where("enumerations.id = #{@category_id} and enumerations.type ='ApkBaseCategory'") } if @category_id.present?
    scope = $db.slave { scope.where(app_category: @app_category) } if @app_category.present?
    scope = $db.slave { scope.where("projects.id = #{@project_id}") } if @project_id.present?
    scope = $db.slave { scope.where("package_name LIKE '%#{@package_name}%'") } if @package_name.present?
    scope = $db.slave { scope.where(integrated: @integrated) } if @integrated.present?
    scope = $db.slave { scope.where(android_platform: @android_platform) } if @android_platform.present?

    @count = scope.length
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @apks = $db.slave { scope.limit(@limit).offset(@offset).to_a }

    @project_apks = $db.slave { ProjectApk.joins(:project).select("projects.name, project_id").uniq }
    @categories = $db.slave { ApkBaseCategory.all }
    respond_to do |format|
      format.html #{ render(:template => 'issues/index', :layout => !request.xhr?) }
      format.xlsx do
        rows = {}
        columns = [{"name" => "APK名称"},
                   {"cn_name" => "中文名"},
                   {"desktop_name" => "桌面显示名称"},
                   {"cn_description" => "功能描述"},
                   {"developer" => "开发者信息"},
                   {"package_name" => "包名"},
                   {"category" => "类别"},
                   {"desktop_icon_text" => "是否有桌面图标"},
                   {"removable_text" => "是否可卸载"},
                   {"os_category_text" => "操作系统类别"},
                   {"production" => "归属产品"},
                   {"app_category_text" => "产品类型"},
                   {"android_platform_text" => "集成Android平台"},
                   {"integrated_text" => "是否集成"}
                  ]
        columns.each { |c| rows.merge!({c.keys.first => c.values.first}) }
        send_data send_to_xlsx(scope, rows), {:disposition => 'attachment', :encoding => 'utf8',
                                       :stream => false, :type => 'application/xlsx',
                                       :filename => "APK基本信息_#{Time.now.strftime('%Y%m%d%H%M%S')}.xlsx"}
      end
    end
  end

  def apks
    @limit = per_page_option

    scope = $db.slave { @project.apk_bases }

    @count = scope.count
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @apks = $db.slave { scope.includes(:project_apk, :apk_base_category).limit(@limit).offset(@offset) }
  end

  def new
    @apk_base = @project.apk_bases.build
    @apk_base.developer = '深圳市金立通信设备有限公司'
    @apk_base.app_category = @project.production_type
    @apk_base.integrated = true
    if params[:format].present? && params[:format] == 'js'
      @apk_base.assign_attributes(apk_base_params)
      render 'info'
    end
  end

  def create
    exist_apk = ApkBase.find_by(name: apk_base_params[:name])
    if exist_apk.present? && exist_apk.app_category.present?
      respond_to do |format|
        format.html  do
          flash[:error] = "#{exist_apk.name.to_s} 已经存在，请重新命名新增APK名称!" 
          redirect_to project_apks_path(@project)
        end
      end
    else
      @apk_base = @project.apk_bases.build
      @apk_base.app_category = @project.production_type
      @apk_base.os_category = 1
      @apk_base.author_id = User.current.id

      result = @apk_base.do_save("add", apk_base_params, @project)

      respond_to do |format|
        if result[:saved]
          exist_apk.destroy if exist_apk.present? && exist_apk.app_category.blank?
          @project_apk = @project.project_apks.build
          @project_apk.apk_base_id = @apk_base.id
          @project_apk.author_id = User.current.id
          @project_apk.save  

          format.html do
            flash[:notice] = l(:notice_successful_create)
            redirect_back_or_default project_apks_path(@project)
          end
        else
          format.html { render :action => 'new' }
        end
      end
    end
  end

  def edit
    if @apk_base.tasks.where(status: 24).count != 0
      flash[:error] = "#{@apk_base.name}处于评审状态，不能进行修改！"
      redirect_back_or_default project_apks_path(@project)
    end

    if params[:format].present? && params[:format] == 'js'
      @apk_base.assign_attributes(apk_base_params)
      render 'info'
    end
  end

  def update
    if @apk_base.tasks.where(status: 24).count != 0
      flash[:error] = "#{@apk_base.name}处于评审状态，不能进行修改！"
      redirect_back_or_default project_apks_path(@project)
    else
      result = @apk_base.do_save('modify', apk_base_params, @project)
      if result[:saved]
        redirect_back_or_default project_apks_path(@project)
      else
        render 'edit'
      end
    end
  end

  def destroy
    @apk_base.do_save('delete', {android_platform: @apk_base.android_platform, integrated: @apk_base.integrated}, @project)
    
    data = {project: @project.name}
    render :json => data.to_json
  end

  def history
    @limit = per_page_option
    scope = AlterRecordDetail.apk_base_details
    @count = scope.count
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @records = scope.limit(@limit).offset(@offset).to_a
  end

  def search
    name = params[:name]
    scope = ApkBase.where("name LIKE '%#{name}%'")
                   .reorder("name asc")
        
    page     = params[:page] || 1
    limit    = 20
    offset   = (page.to_i - 1) * limit
    apks     = scope.limit(limit)
                    .offset(offset)

    respond_to do |format|
      format.js {
        render :json => apks.map{|v| {:id => v.id, :name => v.name}}
      }
    end
  end

  private
  def apk_base_params
    apk_params = params.require(:apk_base).permit(:name, :cn_name, :cn_description, :developer, :desktop_name, :desktop_icon, :package_name, :category_id, :removable, :android_platform, :integrated)
    apk_params[:name] = apk_params[:name].squish if apk_params[:name].present?
    apk_params[:developer] = '深圳市金立通信设备有限公司' if apk_params[:developer].blank? && apk_params[:integrated].to_s != "false"
    return apk_params
  end

  def find_apk_base_categories
    @categories = ApkBaseCategory.active
  end

  def find_apk_base
    @apk_base = ApkBase.find(params[:id])
  end

  def apk_bases_layout
     %w(apks new create edit update).exclude?(params[:action]) ? "repo" : "admin"
  end

  def send_to_xlsx(items, columns)
    items = items || []
    # New xlsx
    package = Axlsx::Package.new
    workbook = package.workbook

    # Style
    styles = workbook.styles
    heading = styles.add_style :border => {:style => :thin, :color => "000000"}, b: true, sz: 12, bg_color: "F77609", fg_color: "FF"
    body = styles.add_style alignment: {horizontal: :left}, :border => {:style => :thin, :color => "000000"}
    warning = styles.add_style alignment: {horizontal: :left}, :border => {:style => :thin, :color => "000000"}, bg_color: "ebccd1"
    notice = styles.add_style alignment: {horizontal: :left}, :border => {:style => :thin, :color => "000000"}, bg_color: "faebcc"

    # Workbook
    workbook.add_worksheet(name: "GIONEE") do |sheet|
      sheet.add_row (columns.values), style: heading

      items.each do |a|
        sheet.add_row (columns.keys.map { |c|
          a.send(c)
        }), style: body
      end
    end

    package.to_stream.read
  end
end
