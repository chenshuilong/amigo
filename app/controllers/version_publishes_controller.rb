class VersionPublishesController < ApplicationController
  model_object VersionPublish
  before_filter :require_login
  before_action :find_model_object, :except => [:index, :preview, :history]
  #before_action :authorize_global, :except => [:add_app, :search_spec_version, :refresh]

  helper :sort
  include SortHelper
  include VersionPublishesHelper

  def index
    auth :version_publish
    sort_init 'created_at', 'desc'
    sort_update 'project' => "#{Project.table_name}.name",
                'spec' => "#{Spec.table_name}.name",
                'version' => "#{Version.table_name}.name",
                'publisher_id' => "#{VersionPublish.table_name}.publisher_id",
                'published_on' => "#{VersionPublish.table_name}.published_on",
                'status'=> "#{Version.table_name}.status"

    @project_ids        = params[:project_ids]
    @spec_ids           = params[:spec_ids]
    @version_ids        = params[:version_ids]
    @publisher          = params[:publisher_id]
    @published_on_start = params[:published_on_start]
    @published_on_end   = (Date.parse(params[:published_on_end]) + 1).to_s         if params[:published_on_end].present?
    
    scope = VersionPublish.index_list

    @projects = Project.default.where(id: scope.map(&:project_id)).pluck(:name, :id)
    @specs    = Spec.group_spec(scope.map(&:project_id), scope.map(&:spec_id))
    @versions = Version.where(id: scope.map(&:version_id)).pluck(:name, :id)

    scope = scope.where(versions: {project_id: @project_ids})                    if @project_ids.present?
    scope = scope.where(spec_id: @spec_ids)                                      if @spec_ids.present?
    scope = scope.where(version_id: @version_ids)                                if @version_ids.present?
    scope = scope.where(publisher_id: @publisher)                                if @publisher.present?
    scope = scope.where(:published_on => @published_on_start..@published_on_end) if @published_on_start.present?

    @count = scope.to_a.count
    @limit = per_page_option
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @version_publishes =  scope.reorder(sort_clause).limit(@limit).offset(@offset).to_a
  end

  def preview
    auth :version_publish
    @spec = Spec.find(params[:spec_id])
    @versions = @spec.versions.where(compile_status: 6).reorder("name asc")
    @need_alert = false

    @current_spec_publishes = @spec.version_publishes.order("created_at asc")
    @last_version_publish = @current_spec_publishes.last
    if params[:version_id].present?
      @version = @versions.find(params[:version_id])
      if @last_version_publish.present?
        if @current_spec_publishes.pluck(:version_id).include?(@version.id.to_i)
          @version_publish = @last_version_publish
        else
          #该规格锁定其他版本
          @rows, @apk_infos, @notes = @version.app_lists.generate_applist_infos(@last_version_publish)
          if @rows.present?
            @notes[0][:version_lock] = {old: @last_version_publish.version.name, new: @version.name}
            @version_publish = VersionPublish.new(publish_params(@spec, @version, @notes, @rows))
            @version_publish.save
            @need_alert = true
          else
            @version_publish = @last_version_publish
          end
        end
      else
        #该规格下第一次锁定版本
        @rows, @apk_infos, @notes = @version.app_lists.generate_applist_infos
        if @rows.present?
          @notes[0][:version_lock] = {old: "无", new: @version.name}
          @version_publish = VersionPublish.new(publish_params(@spec, @version, @notes, @rows))
          @version_publish.save
          @need_alert = true
        end
      end
    else
      if @current_spec_publishes.present?
        @version_publish = @last_version_publish
      end
    end

    if @version_publish.present?
      @content = JSON.parse(@version_publish.content)
      @rows = @version_publish.full_info_json.delete_if{|k, v| k.to_s == "remove_notes" }
      @remove_note = @content["remove_notes"]

      if @need_alert
        @notes = @version_publish.notes
        @can_alert = @notes[0].present? && (@notes[0][:change].present? || @notes[0][:without_apk].present? || @notes[0][:without_content].present?)
      end
    end
  end

  def edit
    auth :version_publish
    @content = JSON.parse(@version_publish.content)
    @rows = @version_publish.full_info_json.delete_if{|k, v| k.to_s == "remove_notes" }
    @remove_note_hash =  @content["remove_notes"].gsub(/\r\n/,"<br/>")
  end

  def save_change
    @new_rows        = params[:rows]
    @old_rows        = params[:old_rows]
    @remove_note     = params[:remove_note].gsub("<br/>", "\r\n")
    @old_remove_note = params[:old_remove_note].gsub("<br/>", "\r\n")

    status, @final_version_publish = @version_publish.compare_and_update(@new_rows, @old_rows, @remove_note, @old_remove_note)
    data = {status: status, version_id: @final_version_publish.version_id, spec_id: @final_version_publish.spec_id}

    render json: data.to_json
  end

  def refresh
    @rows, @full_rows, @notes = @version_publish.version.app_lists.generate_applist_infos
    @data = {rows: @full_rows, remove_note: VersionPermission.find_by(name: "remove_notes").meaning.gsub(/\r\n/,"<br/>")}
    render json: @data.to_json
  end

  def history
    auth :version_publish
    scope = VersionPublish.where(spec_id: params[:spec_id])
    @spec = Spec.find(params[:spec_id])

    @count = scope.count
    @limit = per_page_option
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @version_publishes =  scope.limit(@limit).offset(@offset).to_a
  end

  def publish
    auth :version_publish
    title = params[:xinghao].squish.to_s + " 预置应用公示-" + params[:system_version].to_s.squish
    content = @version_publish.content_publish_to_security(title_params, title)

    puts '-------------------- Title Start --------------------'
    puts content
    puts '-------------------- Title  End  --------------------'
    
    if @version_publish.version.status == 4
      if Api::VersionPublish.publish_security(content)   
        @version_publish.update(publisher_id: User.current.id, published: true, published_on: Time.now) 
        flash[:notice] = "成功上传到官网！"
      else
        flash[:error] = "未成功上传到官网！"
      end
    end
    redirect_to version_publishes_path
  end

  def show
    auth :version_publish
    @spec = @version_publish.spec
    @version = @version_publish.version
    @content = JSON.parse(@version_publish.content)
    @rows = @version_publish.full_info_json.delete_if{|k, v| k.to_s == "remove_notes" }
    @remove_note = @content["remove_notes"]
  end

  def export
    auth :version_publish
    rows = {}
    @version_publish = VersionPublish.find(params[:id])
    @lists = @version_publish.full_info_json
    columns = [{"apk_name" => "APK名称"},
               {"cn_name" => "应用中文名"},
               {"desktop_name" => "桌面显示名称"},
               {"description" => "功能描述"},
               {"developer" => "开发者信息"},
               {"apk_version" => "版本号"},
               {"apk_permission" => "权限"},
               {"apk_removable" => "是否可卸载"}]
    columns.each { |c| rows.merge!({c.keys.first => c.values.first}) }
    send_data send_to_xlsx(@lists, rows), {:disposition => 'attachment', :encoding => 'utf8',
                                           :stream => false, :type => 'application/xlsx',
                                           :filename => "#{@version_publish.version.fullname}_#{Time.now.strftime('%Y%m%d%H%m%s')}.xlsx"}
  end

  def abnormal_report
    if params[:type].present? && params[:type] == 'history'
      @notes = @version_publish.notes
    else
      @current_spec_publishes = @version_publish.spec.version_publishes.where("id < #{@version_publish.id} AND version_id != #{@version_publish.version_id}").order("created_at asc")
      @last_version_publish = @current_spec_publishes.last
      @rows, @apk_infos, @notes = @version_publish.version.app_lists.generate_applist_infos(@last_version_publish)
    end
  end

  private
  def publish_params(spec, version, notes, rows)
    publish_params = {}
    publish_params["spec_id"] = spec.id
    publish_params["version_id"] = version.id
    publish_params["content"] = {}
    publish_params["content"]["title"] = "#{spec.project.name}的官网安全公示"
    publish_params["content"]["remove_notes"] = VersionPermission.find_by(name:"remove_notes").try(:meaning)
    publish_params["content"]["rows"] = rows
    publish_params["content"] = publish_params["content"].to_json
    publish_params["content_md5"] = Digest::MD5.hexdigest(publish_params["content"])
    publish_params["author_id"] = User.current.id
    publish_params["notes"] = notes if notes.present?
    return publish_params
  end

  def title_params
    params.require(:title).permit(:cn_name, :desktop_name, :description, :developer, :version_name, :permission, :removable)
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

      items.each do |k, v|
        if k.to_s == "remove_notes"
          sheet.add_row (["应用卸载及恢复方法说明", v]), style: body
        else
          sheet.add_row (columns.keys.map { |c|
            v[c.to_sym]
          }), style: v[:exist] ? (v[:missing] ? notice : body ) : warning
        end
      end
    end

    package.to_stream.read
  end

end