class SdkVersionReleasesController < VersionReleasesController

  before_action :find_model_object, :only => [:show, :edit, :release, :reupload, :view_log]
  skip_before_action :find_project_from_params
  skip_before_action :verify_authenticity_token, :only => [:upload, :release]
  skip_before_action :authorize, :only => [:show]
  before_action :require_login

  def index
    sort_init 'id', 'desc'
    sort_update %w(id version_id status created_at)

    respond_to do |format|
      format.html {
        @limit = per_page_option
        @status = params[:status]

        scope = VersionReleaseSdk.all
        scope = scope.where("status in (#{@status.map { |sta| Thirdparty::Thirdparty_STATUS[sta.to_sym] }.join(',')})") if @status.present? && @status != [""]

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
  def show; end

  def upload
    @sdk = VersionReleaseSdk.new(upload_params)
    @sdk.author = current_user

    respond_to do |format|
      format.html do
        flash[:notice] = l(:notice_successful_create) if @sdk.save
      end
    end
  end

  def release
    @sdk.status = Thirdparty::Thirdparty_STATUS[:releasing]

    SdkVersionReleaseJob.perform_later(@sdk.id) if @sdk.save

    render :text => {:message => "成功!"}.to_json
  rescue => e
    render :text => {:message => e.to_s}.to_json
  end

  def view_log
    @log = @sdk.parse_log(params[:md5]) if /[0-9a-f]{32}/ === params[:md5]
    render :json => @log
  end

  private

  def upload_params
    params.require(:sdk).permit(:version_id, :status, :note, :yml_result, :maven_result, :release_project_ids)
  end

  def find_model_object
    @sdk = VersionReleaseSdk.find(params[:id])
  end
end
