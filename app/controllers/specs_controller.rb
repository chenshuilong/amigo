class SpecsController < ApplicationController
  before_action :require_login

  layout 'admin'

  helper :sort
  include SortHelper

  def index
    @project_id = params[:project_id]
    @project = Project.find_by_identifier(@project_id)

    respond_to do |format|
      format.html {
        @pages = (params['page'] || 1).to_i
        @limit = (params['per_page'] || 150).to_i

        @specs = @project.specs.undeleted
        @my_productions = my_productions

        unless @specs.blank?
          @spec_id = params[:id].blank? ? @specs.first.id : params[:id]
          @spec = Spec.find(@spec_id)
          if @spec.present?
            @spec_name = @spec.name
            sql = "specs.id = #{@spec_id}"
            sql << " and app.id in (#{@my_productions.ids.join(',')})" if @my_productions.present? && User.current.is_app_spm?(@project)
            @apps = Spec.apps(sql)
            @apps_count = @apps.count
            @apps_pages = Paginator.new @apps_count, @limit, @pages
            @apps = Spec.select_apps(sql).limit(@limit).offset(@limit*(@pages-1))
          end
        end

        @parent = @project.parent.present? ? @project.parent : @project
        @project_ids = {projects: Project.where("id = ? OR parent_id = ?", @parent.id, @parent.id).pluck(:id)}.to_query
      }
      format.api {
        @specs = @project.specs.undeleted.to_a
      }
    end
  end

  def edit
    @project_id = params[:project_id]
    @spec = Spec.find(params[:id])
    find_project @project_id

    if @spec.locked
      render :js => "layer.alert('规格已被锁定，无法修改！');"
    else
      respond_to { |format| format.js }
    end
  end

  def update
    @project_id = params[:project_id]
    @project = Project.find @project_id
    @spec_id = params[:id]
    if @spec_id.to_i == 0
      if @project.specs.undeleted.find_by_name(spec_update_params[:name]).blank?
        spec_params = spec_update_params.dup
        spec_params.delete("copy_project_id")
        spec_params.delete("copy_spec_id")
        spec_params.delete("copy_type")
        spec_params[:name].to_s.split("\n").reject{|spec_name| spec_name.blank?}.each do |spec_name|
          spec_params.delete("name")
          if @project.production_type == 1 || @project.production_type == 3 # App OR Framework
            project_name = @project.identifier + '_'
            spec_name = spec_name.to_s.gsub(%r(#{project_name})i, '')
            spec_params["name"] = spec_name.strip
          elsif @project.production_type == 2 # Modem
            project_name = @project.name.split('_').first # Maybe identifier
            spec_name = spec_name.to_s.gsub(%r(#{project_name})i, '')
            spec_params["name"] = spec_name.strip
          else
            spec_params["name"] = spec_name.strip
          end
          @spec = @project.specs.create(spec_params)
          SpecVersion.copy_all_app_to_project(spec_update_params[:copy_type] ,spec_update_params[:copy_spec_id], @spec.id) if spec_update_params[:copy_type] && spec_update_params[:copy_spec_id]

          generate_alter_records(@spec, SpecAlterRecord::NEW_RECORD, changes_add_spec_update_params)
        end

        respond_to { |format| format.js }
      else
        render :js => "layer.alert('规格名称不要重复！');"
      end
    else
      @spec = Spec.find(@spec_id)

      if @spec.locked
        render :js => "layer.alert('规格已被锁定，无法修改！');"
      else
        if @project.specs.undeleted.where("name = '#{spec_update_params[:name]}' and id <> #{@spec_id}").blank?
          if @spec.versions.count > 0
            render :js => "layer.alert('规格已出版本，无法修改！');"
          else
            changes = []
            changes << {:spec_name => [@spec.name, spec_update_params["name"]]} if @spec.name.to_s != spec_update_params["name"].to_s
            changes << {:spec_jh_collect_finish_dt => [format_date(@spec.jh_collect_finish_dt), spec_update_params["jh_collect_finish_dt"]]} if format_date(@spec.jh_collect_finish_dt).to_s != spec_update_params["jh_collect_finish_dt"].to_s
            changes << {:spec_note => [@spec.note, spec_update_params["note"]]} if @spec.note.to_s != spec_update_params["note"].to_s
            changes << {:spec_for_new => [@spec.for_new, spec_update_params["for_new"]]} if @spec.for_new.to_s != spec_update_params["for_new"].to_s
            generate_alter_records(@spec, SpecAlterRecord::UPDATE_RECORD, changes)

            @spec.update_attributes(spec_update_params)

            respond_to { |format| format.js }
          end
        else
          render :js => "layer.alert('规格名称不要重复！');"
        end
      end
    end
  end

  def destroy
    @spec_id = params[:id]
    @spec = Spec.find(@spec_id)
    if @spec.locked || @spec.freezed
      render :text => {:message => "layer.alert('规格已被冻结或者锁定，无法删除！');"}.to_json
    elsif !@spec.versions.blank?
      render :text => {:message => "layer.alert('规格已出版本，无法删除！');"}.to_json
    else
      generate_alter_records(@spec, SpecAlterRecord::DELETE_RECORD, [{:spec_name => [@spec.name, @spec.name]}])

      @spec.deleted = true
      @spec.save!

      render :text => {:message => "$('[data-id=\"spec-#{@spec_id}\"]').remove();layer.alert('删除成功！');"}.to_json
    end
  end

  def export
    rows = {}
    @project_id = params[:project_id]
    @project = Project.find_by_identifier(@project_id)
    @specs = @project.specs.undeleted
    columns = [{"name" => "规格名称"},
               {"jh_collect_finish_dt" => "计划收集完成时间"},
               {"sj_collect_finish_dt" => "实际收集完成时间"},
               {"note" => "备注"}]
    columns.each { |c| rows.merge!({c.keys.first => c.values.first}) }
    send_data data_to_xlsx(@specs, rows).to_stream.read, {:disposition => 'attachment', :encoding => 'utf8',
                                           :stream => false, :type => 'application/xlsx',
                                           :filename => "#{Time.now.strftime('%Y%m%d%H%m%s')}.xlsx"}
  end

  def export_apps
    rows = {}
    @spec_id = params[:spec_id]
    @spec = Spec.find(params[:spec_id])
    @apps = Spec.select_apps("spec_versions.spec_id = #{@spec_id}")
    columns = [{"app_name" => "应用名称"},
               {"app_version" => "应用版本"},
               {"cn_name" => "应用中文名"},
               {"desktop_name" => "桌面显示名称"},
               {"developer" => "开发者信息"},
               {"mark" => "功能描述"},
               {"app-spms" => "APP-SPMS"},
               {"app_updated_on" => "修改时间"},
               # {"jh_collect_finish_dt" => "计划收集完成时间"},
               # {"sj_collect_finish_dt" => "实际收集完成时间"},
               {"mark" => "功能描述"}]
    columns << {"release_path" => "发布路径"} if @spec && @spec.for_new != 3
    columns.each { |c| rows.merge!({c.keys.first => c.values.first}) }
    send_data export_app_to_xlsx(@apps, rows), {:disposition => 'attachment', :encoding => 'utf8',
                                          :stream => false, :type => 'application/xlsx',
                                          :filename => "#{Time.now.strftime('%Y%m%d%H%m%s')}.xlsx"}
  end

  def editapp
    @project_id = params[:project_id]
    @project = Project.find_by_identifier(@project_id)
    @spec = Spec.find(params[:spec_id])
    @app = Spec.select_apps("spec_versions.id = #{params[:appid]}").first
    @my_productions = my_productions

    if (@spec.locked || @spec.freezed) && !(User.current.admin || User.current.is_spm?(Project.find(@project_id)))
      render :js => "layer.alert('规格已被冻结或者锁定，无法编辑！');"
    else
      respond_to { |format| format.js }
    end
  end

  def frost
    @project_id = params[:project_id]
    @project = Project.find_by_identifier(@project_id)
    @spec = Spec.find(params[:spec_id])

    if (@spec.locked || @spec.freezed) && !(User.current.admin || User.current.is_spm?(@project))
      render :js => "layer.alert('规格已被冻结或者锁定，无法编辑！');"
    else
      app_version = SpecVersion.find(params["appid"])
      app_version.freezed = params["freeze"]
      if app_version.save
        record = SpecAlterRecord.new
        record.spec_id = @spec.id
        record.record_type = SpecAlterRecord::FREEZED_RECORD
        record.prop_key = "app_freeze"
        record.user_id = User.current.id
        record.app_id = app_version.production_id
        record.old_value = !app_version.freezed
        record.value = app_version.freezed
        record.save
      end

      if params[:sync].is_a?(Hash)
        params[:sync].each do |app_id, sync|
          if sync.to_i == 1
            sv = SpecVersion.find(app_id.to_s.split('_')[1])
            sv.freezed = params["freeze"]
            SpecAlterRecord.create({:user_id => User.current.id,
                                    :spec_id => sv.spec_id,
                                    :record_type => SpecAlterRecord::FREEZED_RECORD,
                                    :prop_key => "app_freeze",
                                    :app_id => sv.production_id,
                                    :old_value => !app_version.freezed,
                                    :value => app_version.freezed
                                   }) if sv.save
          end
        end
      end

      respond_to { |format| format.html }
    end
  end

  def udapp
    @spec_id = params[:spec_id]
    @spec = Spec.find @spec_id
    @appid = params[:appid]

    if (@spec.locked || @spec.freezed) && !(User.current.admin || User.current.is_spm?(Project.find(@spec.project_id)))
      render :js => "layer.alert('规格已被冻结或者锁定，无法修改！');"
    else
      if @appid.to_i == 0
        pid = app_update_params[:production_id]
        @spec_version = SpecVersion.where(:spec_id => @spec_id, :production_id => pid, :deleted => false).first
        if @spec_version.present?
          @app = Spec.select_apps("spec_versions.id = #{@spec_version.id}").first

          sync_parent_and_children_app_version
          respond_to { |format| format.js }
        else
          @app = SpecVersion.create(app_update_params)
          generate_alter_records(@spec, SpecAlterRecord::NEW_RECORD, changes_add_app_update_params)
          @app = Spec.select_apps("spec_versions.id = #{@app.id}").first

          sync_parent_and_children_app_version
          respond_to { |format| format.js }
        end
      else
        @app = SpecVersion.find(@appid)
        generate_app_alter_records(@spec, SpecAlterRecord::UPDATE_RECORD, @app)

        @app.update_attributes(app_update_params)
        @app = Spec.select_apps("spec_versions.id = #{@appid}").first

        sync_parent_and_children_app_version
        respond_to { |format| format.js }
      end
    end
  end

  def delapp
    @app = SpecVersion.find(params[:appid])
    @app_name = Production.find(@app.production_id).name
    @spec = Spec.find(@app.spec_id)

    if (@spec.locked || @spec.freezed) && !(User.current.admin || User.current.is_spm?(Project.find(@project_id)))
      render :text => {:message => "layer.alert('规格已被冻结或者锁定，无法删除该应用！');"}.to_json
    else
      generate_alter_records(@spec, SpecAlterRecord::DELETE_RECORD, [{:app_name => [@app_name, @app_name]}])

      @app.deleted = true
      @app.deleted_at = Time.now
      @app.save!
      if params[:sync].is_a?(Hash)
        params[:sync].each do |app_id, sync|
          if sync.to_i == 1
            sv = SpecVersion.find(app_id.to_s.split('_')[1])
            sv.deleted = true
            SpecAlterRecord.create({:user_id => User.current.id,
                                    :spec_id => sv.spec_id,
                                    :record_type => SpecAlterRecord::DELETE_RECORD,
                                    :prop_key => "app_name",
                                    :old_value => Production.find(sv.production_id).name,
                                    :value => Production.find(sv.production_id).name
                                   }) if sv.save
          end
        end
      end

      render :text => {:message => "$('[data-id=\"app-#{@app.id}\"]').remove();layer.alert('删除成功！');"}.to_json
    end
  end

  def reset
    @is_default = params[:is_default] || true
    @spec = Spec.find(params[:spec_id])
    @project = Project.find(@spec.project_id)
    @defaults = @project.specs.default

    raise "不能同时设置两个默认规格" if @defaults.count > 1

    generate_alter_records(@spec, SpecAlterRecord::RESET_RECORD, [{:spec_reset => [@defaults.blank? ? "" : @defaults.first.name, @spec.name]}])

    @spec.is_default = true
    @spec.save

    @project.specs.where("specs.id <> #{@spec.id}").each do |spec|
      spec.is_default = false
      spec.save
    end

    render :text => {:message => "设置成功!"}.to_json
  rescue => e
    render :text => {:message => e.to_s}.to_json
  end

  def lock
    @is_locked = params[:locked]
    @spec = Spec.find(params[:spec_id])

    changes = [{:spec_locked => [@spec.locked ? 1 : 0, @spec.locked ? 0 : 1]}]
    generate_alter_records(@spec, SpecAlterRecord::LOCKED_RECORD, changes)

    @spec.locked = @is_locked
    @spec.sj_collect_finish_dt = Time.now.to_s(:db) if @spec.sj_collect_finish_dt.blank?
    @spec.save

    render :text => {:message => "#{!@spec.locked ? '解锁' : '锁定'}成功!"}.to_json
  rescue => e
    render :text => {:message => e.to_s}.to_json
  end

  def freeze
    @is_freezed = params[:freezed]
    @spec = Spec.find(params[:spec_id])

    changes = [{:spec_freezed => [@spec.freezed ? 1 : 0, @spec.freezed ? 0 : 1]}]
    generate_alter_records(@spec, SpecAlterRecord::FREEZED_RECORD, changes)

    @spec.freezed = @is_freezed
    @spec.save

    render :text => {:message => "#{!@spec.freezed ? '解冻' : '冻结'}成功!"}.to_json
  rescue => e
    render :text => {:message => e.to_s}.to_json
  end

  def alter_records
    @spec_id = params[:spec_id]

    if @spec_id.present?
      @spec = Spec.find(params[:spec_id])
      @spec_name = @spec.name
      @records = @spec.spec_alter_records
    end

    respond_to { |format| format.js }
  end

  def collct
    if params[:spec_id]
      @project_id = params[:project_id]
      @project = Project.find(@project_id)

      SpecVersion.collect_all_app_list(params[:spec_id], @project)
      Notification.send_mission_to_app_spm_of_project(params[:spec_id], @project)

      @spec = Spec.find(params[:spec_id])
      @spec.is_colleted = true
      generate_alter_records(@spec, SpecAlterRecord::COLLECT_RECORD, [{:spec_collected => [0, 1]}]) if @spec.save
    else
      @project_id = params[:specs][:project_id]
    end

    render :js => "layer.alert('发送收集成功！');setTimeout(function () {window.location.reload();}, 1500);"
  rescue => e
    render :js => "layer.alert('发送收集失败,原因：#{e.message.to_s}！');"
  end

  def get_app_versions
    app = find_project(params[:pid])
    opts = app.versions.main_versions.map { |v|
      if app.production_type.to_i.in?([Project::PROJECT_PRODUCTION_TYPE[:preload], Project::PROJECT_PRODUCTION_TYPE[:resource]])
        [v.id, v.spec.name]
      else
        [v.id, v.spec.name + "_" + v.name.gsub(".#{v.name.to_s.split('.')[-1]}", "")]
      end
    }

    render :text => {:success => 1, :app_cn_name => app.cn_name || "", :rows => opts.uniq}.to_json
  rescue => e
    render :text => {:success => 0, :rows => e.to_s}.to_json
  end

  def get_project_specs
    project = find_project(params[:pid])
    specs   = project.specs.undeleted
    specs   = specs.loccked if project.category.to_i != 4

    render :text => {:success => 1, :rows => specs.map { |s| [s.id, s.name] }.unshift(["","--请选择--"])}.to_json
  rescue => e
    render :text => {:success => 0, :rows => e.to_s}.to_json
  end

  def get_spec_main_versions
    spec     = params[:spec_id].blank? ? [] : Spec.find(params[:spec_id])
    is_main  = string_to_boolean(params[:is_main])
    versions = spec.blank? ? [] : (is_main ? spec.versions.main_versions : spec.versions)

    render :text => {:success => 1, :rows => versions.map { |v| [v.id, is_main ? v.name.gsub("#{v.name.to_s.split('.')[-1]}","") : v.name] }}.to_json
  rescue => e
    render :text => {:success => 0, :rows => e.to_s}.to_json
  end

  def get_parent_and_children_spec_version
    project = Project.find_by_identifier params[:project_id]
    rows = User.current.is_spm?(project) ? find_app_spec_version(project, params[:spec_id], params[:appid]) : []

    render :text => {:success => 1, :rows => rows}.to_json
  rescue => e
    render :text => {:success => 0, :rows => e.to_s}.to_json
  end

  # projects' specs list and search
  def list
    if policy(:spec).view_all?
      @all_projects = Project.active.visible.default.pluck(:name, :id)
    elsif policy(:spec).view_own?
      @all_projects = User.current.projects.active.visible.default.pluck(:name, :id)
    end

    if @all_projects.present?
      sort_init 'id', 'desc'
      sort_update 'id' => "#{Spec.table_name}.id",
                  'name' => "#{Spec.table_name}.name",
                  'project_name' => "#{Project.table_name}.name",
                  'created_at' => "#{Spec.table_name}.created_at"  

      @projects            = params[:projects]
      @specs               = params[:specs] || ''
      @author              = params[:author]
      @created_at_start    = params[:created_at_start]
      @created_at_end      = (Date.parse(params[:created_at_end]) + 1).to_s    if params[:created_at_end].present?  

      scope = Spec.joins(:project).where.not(projects: {category: 4}).where(project_id: @all_projects.map{|a| a[1]})
      scope = scope.where(:project_id => @projects)                            if @projects.present?
      scope = scope.where(:created_at => @created_at_start..@created_at_end)   if @created_at_start.present?
      scope = scope.where(id: @specs)                                          if @specs.present?
      scope = scope.search_author(@author)                                     if @author.present?  

      @limit  = params[:per_page].present? ? params[:per_page].to_i : 25
      @page   = params[:page].present? ? params[:page].to_i : 1
      @offset = (@page-1) * @limit
      @count  = scope.to_a.count
      @pages  = Paginator.new @count, @limit, @page  

      @specs  =  scope.reorder(sort_clause).limit(@limit).offset(@offset).to_a
      @select_specs =  Spec.version_search('', @projects)
    end
  end

  #specs compare
  def compare
    @projects = params[:projects] || (params[:specs].present? ? Spec.where(id: params[:specs]).map(&:project_id) : [])
    @specs    = params[:specs]

    @specs = @specs.map(&:to_i).sort if @specs.present?

    @apps =  SpecVersion.search(@specs)

    @select_specs = Spec.version_search('', @projects)
    if policy(:spec).view_all?
      @all_projects = Project.active.visible.default.pluck(:name, :id)
    elsif policy(:spec).view_own?
      @all_projects = User.current.projects.active.visible.default.pluck(:name, :id)
    end
  end

  def update_specs
    @projects = params[:name]

    @select_specs = Spec.version_search('', @projects)

    respond_to do |format|
      format.js
    end
  end

  def export_compare_specs
    rows = {}
    @specs = params[:specs]
    @specs = @specs.map(&:to_i).sort if @specs.present?
    
    @apps = SpecVersion.search(@specs)

    version_head = []
    @specs.each do |spec|
      version_head << {"app_versions_#{spec}" => Spec.find(spec).fullname}
    end

    columns = [{"production_id" => "序号"}, {"app_name" => "应用"}] + version_head
    columns.each { |c| rows.merge!({c.keys.first => c.values.first}) }

    send_data spec_to_xlsx(@apps, rows), {:disposition => 'attachment', :encoding => 'utf8',
                                          :stream => false, :type => 'application/xlsx',
                                          :filename => "specs_compare_#{Time.now.strftime('%Y%m%d%H%m%s')}.xlsx"}
  end

  private

  def spec_update_params
    params.require(:specs).permit(:name, :jh_collect_finish_dt, :sj_collect_finish_dt, :note, :for_new, :copy_project_id, :copy_spec_id, :copy_type)
  end

  def app_update_params
    params.require(:specs).permit(:spec_id, :production_id, :version_id, :mark, :release_path, :freezed, :cn_name, :developer, :desktop_name)
  end

  def changes_add_spec_update_params
    spec_update_params.find_all { |key, value| value.strip.length > 0 }.map { |p| {("spec_" + p[0]).to_sym => ["", p[1]]} }
  end

  def changes_add_app_update_params
    app_update_params.delete(:spec_id)
    app_update_params.find_all { |key, value| key.to_s != "spec_id" && value.strip.length > 0 }.map { |p| {("app_" + p[0]).to_sym => ["", p[1]]} }
  end

  def record_prop_keys
    %W{name locked jh_collect_finish_dt note}
  end

  def generate_alter_records(spec, record_type, changes = [])
    changes.each do |change|
      change.each do |key, value|
        SpecAlterRecord.create(:spec_id => spec.id, :user_id => User.current.id,
                               :record_type => record_type, :prop_key => key.to_s,
                               :old_value => value[0], :value => value[1])
      end
    end
  end

  def generate_app_alter_records(spec, record_type, app)
    app_update_params.each do |key, value|
      SpecAlterRecord.create(:spec_id => spec.id, :user_id => User.current.id,
                             :app_id => app.production_id, :record_type => record_type, :prop_key => "app_" + key.to_s,
                             :old_value => app.send(key), :value => value) if app.send(key).to_s != value.to_s
    end
  end

  def my_productions
    User.current.is_spm?(@project) ? Production.useful : User.current.productions
  end

  def find_project(project_id)
    @project = Project.find(project_id)
  end

  def find_app_spec_version(project, spec_id, production_id)
    specids = []
    if project.parent_id.present?
      pids = project.parent.all_down_children
    else
      pids = project.all_down_children
    end

    Project.where(:id => pids).each { |p| specids << p.specs.map { |spec| spec.id } }
    specids = specids.flatten.uniq - [spec_id.to_i]
    sql = "specs.id in (#{specids.join(',')}) and spec_project.ownership = #{project.ownership}"
    sql = "spec_versions.spec_id in (#{specids.join(',')}) and spec_versions.production_id = #{production_id} and spec_project.ownership = #{project.ownership}" if params[:is_new].to_s == "false"
    apps = params[:is_new].to_s == "false" ? Spec.select_apps(sql).reorder("spec_project.name") : Spec.pd_apps(sql, production_id).reorder("spec_project.name")
    specids.flatten.uniq.blank? ? [] : apps
  end

  def sync_parent_and_children_app_version
    if params[:sync].is_a?(Hash)
      params[:sync].each do |app_id, sync|
        if sync.to_i == 1
          spv_id = app_id.to_s.split('_')[1].to_i
          spec_id = app_id.to_s.split('_')[2].to_i
          if spv_id == 0
            sv = SpecVersion.new
            sv.spec_id = spec_id
            sv.production_id = app_update_params[:production_id]
          else
            sv = SpecVersion.find(spv_id)
            @old_version_id = sv.version_id
          end
          sv.version_id = app_update_params[:version_id]
          sv.cn_name = app_update_params[:cn_name]
          sv.developer = app_update_params[:developer]
          sv.desktop_name = app_update_params[:desktop_name]
          sv.mark = app_update_params[:mark]
          SpecAlterRecord.create({:user_id => User.current.id,
                                  :spec_id => sv.spec_id,
                                  :record_type => sv.new_record? ? SpecAlterRecord::NEW_RECORD : SpecAlterRecord::UPDATE_RECORD,
                                  :prop_key => "app_version_id",
                                  :app_id => sv.production_id,
                                  :value => app_update_params[:version_id].to_i,
                                  :old_value => sv.new_record? ? 0 : @old_version_id
                                 }) if sv.save
        end
      end
    end
  end

  def spec_to_xlsx(items, columns)
    items = items || []
    # New xlsx
    package = Axlsx::Package.new
    workbook = package.workbook

    # Style
    styles = workbook.styles
    heading = styles.add_style alignment: {horizontal: :center}, :border => {:style => :thin, :color => "000000"}, b: true, sz: 12, bg_color: "F77609", fg_color: "FF"
    body = styles.add_style alignment: {horizontal: :center}, :border => {:style => :thin, :color => "000000"}
    diff = styles.add_style alignment: {horizontal: :center}, :border => {:style => :thin, :color => "A94442"}, fg_color: "A94442"

    # Workbook
    workbook.add_worksheet(name: "GIONEE") do |sheet|
      sheet.add_row (columns.values), style: heading
      s_count = @specs.count

      items.each_with_index do |item, index|
        style = (item.v_count >= s_count && item.v_uniq > 1) || item.v_count < s_count ? diff : body
        version = []
        @specs.each_with_index do |v, i|
          version << item.version_name(v)
        end
        sheet.add_row [index+1, item.app_name]+version, style: style
      end
    end

    package.to_stream.read
  end

  def export_app_to_xlsx(items, columns)
    items = items || []
    # New xlsx
    package = Axlsx::Package.new
    workbook = package.workbook

    # Style
    styles = workbook.styles
    heading = styles.add_style :border => {:style => :thin, :color => "000000"}, b: true, sz: 12, bg_color: "F77609", fg_color: "FF"
    body = styles.add_style alignment: {horizontal: :left}, :border => {:style => :thin, :color => "000000"}

    # Workbook
    workbook.add_worksheet(name: "GIONEE") do |sheet|
      sheet.add_row (columns.values), style: heading
      items.each do |item|
        sheet.add_row (columns.keys.map { |c|
          if c == "app-spms"
            Member.select("users.id spms").users_role_project(item.production_id, "APP-SPM").map{|m| User.find(m.spms).name}.join(',')
          else
            item.class == Hash ?
              (c.to_s.end_with?('_dt') || c.to_s.end_with?('_at') || c.to_s.end_with?('_on') ? (item[c.to_s.to_sym]) : item[c.to_s.to_sym]) :
                  (c.to_s.end_with?('_dt') || c.to_s.end_with?('_at') || c.to_s.end_with?('_on') ? item.send(c) : item.send(c))
          end
        }), style: body
      end
    end

    package.to_stream.read
  end
end
