class ThirdpartyVersionReleasesController < VersionReleasesController

  before_action :find_model_object, :only => [:show, :edit, :release, :reupload, :view_log]
  skip_before_action :find_project_from_params
  skip_before_action :verify_authenticity_token, :only => [:upload, :release]
  skip_before_action :authorize, :only => [:show]
  before_action :require_login

  def index
    sort_init 'id', 'desc'
    sort_update %w(id category version_ids status created_at)
    respond_to do |format|
      format.html {
        @specs = []
        @limit = per_page_option
        @status = params[:status]
        @spec_id = params[:spec_id]
        @category = params[:cate].to_i

        apps = Production.active.send(@category == 1 ? "preload_apps" : "resource_apps")
        apps.each { |pd| pd.specs.each { |spec| @specs << [spec.name, spec.id] if @specs.find {|sp| sp.first.to_s.eql?(spec.name)}.blank? } }

        scope = thirdparty_apps_by_category @category
        scope = scope.where("status in (#{@status.map { |sta| Thirdparty::Thirdparty_STATUS[sta.to_sym] }.join(',')})") if @status.present? && @status != [""]
        scope = scope.where(:spec_id => @spec_id) if @spec_id.present?

        @release_count = scope.count
        @release_pages = Paginator.new @release_count, @limit, params['page']
        @offset ||= @release_pages.offset
        @releases = scope.blank? ? scope : scope.limit(@limit).offset(@offset).to_a
      }
      format.api {
        render_api_ok
      }
    end
  end

  def create; end

  def show
    # @third.extract_and_make_mk if @third.version_ids.blank?
  end

  def upload
    @third = Thirdparty.new(upload_params)
    @third.author = User.current
    # @third.status = Thirdparty::Thirdparty_STATUS[:uploading]
    @third.save_attachments(params[:attachments]) if params[:attachments]

    respond_to do |format|
      format.html do
        if @third.save
          render_attachment_warning_if_needed(@third)

          flash[:notice] = l(:notice_successful_create)
        end
        flash[:notice] = l(:notice_successful_create)
      end
    end
  end

  def reupload
    if @third.preload?
      @third.upload_zip_to_server
    end

    render :text => {:message => "成功!"}.to_json
  rescue => e
    render :text => {:message => e.to_s}.to_json
  end

  def release
    @third.release_ids = params[:release_vids]
    @third.status = Thirdparty::Thirdparty_STATUS[:releasing]

    if @third.save
      if @third.preload?
        ThirdpartyVersionReleaseJob.perform_later(@third.id)
      elsif @third.resource?
        ResourceVersionReleaseJob.perform_later(@third.id)
      end
    end

    render :text => {:message => "成功!"}.to_json
  rescue => e
    render :text => {:message => e.to_s}.to_json
  end

  def view_log
    @log = @third.parse_log(params[:md5]) if /[0-9a-f]{32}/ === params[:md5]
    render :json => @log
  end

  private

  def upload_params
    params.require(:thirdparty).permit(:spec_id, :note, :status, :category, :release_type)
  end

  def find_model_object
    @third = Thirdparty.find(params[:id])
  end

  def thirdparty_apps_by_category(cate = 1)
    case cate
      when Thirdparty::Thirdparty_CATEGORY[:preload]
        Thirdparty.preload_apps
      when Thirdparty::Thirdparty_CATEGORY[:resource]
        Thirdparty.resource_apps
      else
        Thirdparty.preload_apps
    end
  end

end
