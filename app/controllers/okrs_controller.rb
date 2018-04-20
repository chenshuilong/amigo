class OkrsController < ApplicationController
  before_filter :require_login

  accept_api_auth :create, :update

  layout 'repo'
  
  def my
    @current_user = User.current
    scope = @current_user.okrs_records.includes(:approver)

    @limit = per_page_option
    @count = scope.count
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @okrs = scope.limit(@limit).offset(@offset).reorder("created_at desc").to_a

    @approvings = OkrsRecord.where(status: %w(approving other_scoring), approver_id: current_user.id)

    @supports = OkrsSupport.my

    if @current_user.admin?
      @setting = OkrsSetting.last || OkrsSetting.new
    end
  end

  def index
    @status = params[:status]
    @date = params[:date]
    @dept = params[:dept] || User.current.dept.try(:id) || 2
    @user = params[:user]

    scope = OkrsRecord.all.includes(:approver)

    scope = scope.where(status: @status) if @status.present?
    scope = scope.search_of_date(@date.split('-').map(&:to_i).join('-')) if @date.present?
    scope = scope.where(author_id: @user) if @user.present?

    if @dept.present? && @dept.to_i != 2
      dept_users = Dept.find_by(id: @dept).all_users.select("users.id").map(&:id)
      scope = scope.where(author_id: dept_users)
    end

    @limit = per_page_option
    @count = scope.count
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @okrs = scope.limit(@limit).offset(@offset).reorder("created_at desc").to_a

    @depts = Dept.get_dept_tree_by_orgNo(["10100001"])
    @select_dept = Dept.find(@dept)
    @users = @select_dept.all_users.active.select(:firstname, :id).pluck(:firstname, :id)
  end

  def new
    if User.current.okrs_records.where.not(status: "finished").count != 0
      flash[:error] = "你还有未完成的OKR, 不能创建新的OKR！"
      redirect_back_or_default my_okrs_path
    else
      @okr = OkrsRecord.new
    end
    @type = "my"
  end

  def create
    @okr = OkrsRecord.new
    saved, messages = @okr.do_save(okrs_params)
    
    respond_to do |format|
     if saved
        format.api  { render :text => {:success => 1, :message => l(:notice_successful_create), :id => @okr.id}.to_json }
      else
        format.api  { render :text => {:success => 0, :message => messages}.to_json }
      end
    end
  end

  def edit
    @okr = OkrsRecord.find(params[:id])
    @okr_table = @okr.table_info
    @records = @okr.alter_records.reorder("created_at desc")
    @type = params[:category]
  end

  def update
    @type = params[:category]
    @okr = OkrsRecord.find(params[:id])

    if params[:type].blank?
      saved, messages = @okr.do_save(okrs_params)
    elsif params[:type].present? 
      saved, messages = @okr.do_save_notes(okrs_params) if params[:type] == "edit_notes"
    end
    respond_to do |format|
     if saved
        format.api  { render :text => {:success => 1, :message => l(:option_message_suc), :id => @okr.id}.to_json }
      else
        format.api  { render :text => {:success => 0, :message => messages}.to_json }
      end
    end
  end

  def destroy; end

  def score
    @result = OkrsKeyResult.find(params[:id])
    saved, status = @result.save_score(params[:data])
    render :json => {saved: saved, status: status}.to_json
  end

  def set_to_mine
    @type = params[:type]
    @category = params[:category]
    case @type
    when 'object'
      @obj = OkrsObject.find(params[:id])
      @okr = @obj.container
    when 'result'
      @obj = OkrsKeyResult.find(params[:id])
      @okr = @obj.container.container
    end
    message = @okr.set_to_mine(@obj, @category)

    render :json => {message: message}.to_json
  end

  def export
    @ids = params[:ids].split(",")
    if @ids.present?
      @okrs = OkrsRecord.where(id: @ids).reorder("created_at desc")
    end
    respond_to do |format|
      format.html
      format.xlsx do
        rows = {}
        columns = [{"object_name" => l(:okrs_objects_name)},
               {"name" => l(:okrs_key_result_name)},
               {"supported_by" => l(:okrs_key_result_supported_by)},
               {"self_score" => l(:okrs_key_result_self_score)},
               {"other_score" => l(:okrs_key_result_other_score)}]
        columns.each { |c| rows.merge!({c.keys.first => c.values.first}) }
        send_data send_to_xlsx(@okrs, rows), {:encoding => 'utf8',
                                           :stream => false, :type => 'application/xlsx',
                                           :filename => "okrs_#{Time.now.strftime('%Y%m%d%H%M%S')}.xlsx"}
      end
      format.pdf {
        send_file_headers! :type => 'application/pdf', :filename => "okrs_#{Time.now.strftime('%Y%m%d%H%M%S')}.pdf"
      }
    end
  end

  def recall
    @ids = params[:ids].split(",")

    if @ids.present?
      status, message = OkrsRecord.recall(@ids)
    else
      status = false
      message = "请选择要撤回的OKR!"
    end

    render json: {status: status, message: message}.to_json
  end

  private
  def okrs_params
    params.require(:okrs_record)
  end

  def send_to_xlsx(items, columns)
    items = items || []
    # New xlsx
    package = Axlsx::Package.new
    workbook = package.workbook

    # Style
    styles = workbook.styles
    heading = styles.add_style alignment: {horizontal: :center}, :border => {:style => :thin, :color => "000000"}, b: true, sz: 12, fg_color: "000000"
    body = styles.add_style alignment: {horizontal: :center}, :border => {:style => :thin, :color => "000000"}

    # Workbook
    items.each do |item|
      item_title = "#{item.title}_#{item.id}"
      workbook.add_worksheet(name: item_title ) do |sheet|
        sheet.add_row [item.title], style: heading
        sheet.merge_cells "A1:E1"
        sheet.add_row (columns.values), style: heading
        objects = item.objects.reorder("created_at")
        
        table_index = 3
        objects.each do |object|
          add_rows = object.results.count - 1
          object.results.each do |result|
            @users = result.supports.map(&:user_name).join(", ")
            current_rows = [object.name, result.name, @users, result.self_score, result.other_score]
            sheet.add_row current_rows, style: body
          end

          sheet.merge_cells "A#{table_index}:A#{table_index+add_rows}"
          table_index = table_index + add_rows + 1
        end
      end
    end

    package.to_stream.read
  end
end
