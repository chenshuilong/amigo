class ProductionsController < ApplicationController
  include Pundit
  include ProductionsHelper
  before_action :require_login
  before_action -> {authorize_global 'projects'}, :only => :new

  layout :productions_layout

  def index
    @type = params[:type]
    @active_productions = $db.slave { Production.classify(true) }
    @unactive_productions = $db.slave { Production.classify(false) }
    @active_total = 0
    @unactive_total = 0

    if @type.present?

      @my_productions = $db.slave { User.current.productions }
      @productions = policy(:production).view_all? ? $db.slave { Production.all } : @my_productions

      @productions = $db.slave { @productions.where(:production_type => @type) }
      @my_productions = $db.slave { @my_productions.where(:production_type => @type) }

      if params[:closed]
        @productions = $db.slave { @productions.where("status <> #{params[:closed]}") }
        @my_productions = $db.slave { @my_productions.where("status <> #{params[:closed]}") }
      else
        @productions = $db.slave { @productions.active }
        @my_productions = $db.slave { @my_productions.active }
      end
    end
  end

  def new
    @type = params[:type]
    @issue_custom_fields = IssueCustomField.sorted.to_a
    @trackers = Tracker.sorted.to_a
    @project = Project.new
    @project.category = 4
    @project.safe_attributes = params[:project]
  end

  def members
    auth :production
    @dev_department = params[:dev_department]
    @production_type = params[:production_type]
    @project_ids = params[:project_ids]
    @apk_bases_ids = params[:apk_base_ids]

    scope = $db.slave { Project.app_members }

    scope = $db.slave { scope.where(dev_department: @dev_department) }                  if @dev_department.present?
    scope = $db.slave { scope.where(production_type: @production_type) }                if @production_type.present?
    scope = $db.slave { scope.where(id: @project_ids) }                                 if @project_ids.present?
    scope = $db.slave { scope.joins(:apk_bases).where(apk_bases:{id: @apk_bases_ids}) } if @apk_bases_ids.present?

    @limit = per_page_option
    @count = scope.length
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @apps = $db.slave { scope.limit(@limit).offset(@offset).to_a }

    @roles = Production::ROLES.collect{|k, v| [v[0], v[1]]}
    @apks = $db.slave { ApkBase.select("id, name").where(id: @apk_bases_ids) }
    @projects = $db.slave { Project.select("id, identifier").where(id: @project_ids) }

    respond_to do |format|
      format.html #{ render(:template => 'issues/index', :layout => !request.xhr?) }
      format.xlsx do
        rows = {}
        columns = [{"dev_department" => "产品团队"},
                   {"production_type" => "产品类型"},
                   {"name" => "应用"},
                   {"apks" => "APK"},
                   {"roles_57" => "Bug Owner"},
                   {"roles_56" => "部门经理"},
                   {"roles_27" => "APP-SPM"},
                   {"roles_20" => "APP-PD"},
                   {"roles_23" => "APP-PO"},
                   {"roles_21" => "APP-UED"},
                   {"roles_24" => "APP-DE"},
                   {"roles_22" => "APP-测试工程师"},
                   {"has_adapter_report" => "是否有适配报告"},
                   {"notes" => "备注"}
                  ]
        columns.each { |c| rows.merge!({c.keys.first => c.values.first}) }
        send_data send_members_to_xlsx(scope, rows), {:disposition => 'attachment', :encoding => 'utf8',
                                       :stream => false, :type => 'application/xlsx',
                                       :filename => "成员信息管理_#{Time.now.strftime('%Y%m%d%H%M%S')}.xlsx"}
      end
    end
  end

  def edit_info
    auth :production
    @project = Project.find(params[:id])
  end

  def update_info
    auth :production
    @project = Project.find(params[:id])
    @project.init_alter
    @project.update(params[:project])
    if @project.has_adapter_report.present?
      has_adapter_report = @project.has_adapter_report ? "是" : "否" 
    else
      has_adapter_report = ""
    end
    result = {has_adapter_report: has_adapter_report , notes: @project.notes.to_s}
    render json: result.to_json
  end

  def records
    auth :production
    scope = $db.slave { AlterRecord.joins(:details)
                            .includes(:user)
                            .includes(:alter_for)
                            .where(alter_for_type: "Project", alter_record_details: {prop_key: %w(has_adapter_report notes)}) }

    @limit = per_page_option
    @count = scope.length
    @pages = Paginator.new @count, @limit, params['page']
    @offset ||= @pages.offset
    @records = $db.slave { scope.limit(@limit).offset(@offset).to_a }
  end

  private
  def productions_layout
    %w(members records).include?(params[:action]) ? "repo" : "admin"   
  end  

  def send_members_to_xlsx(items, columns)
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
          if c.include?("roles_")
            role_id = c.split("_")[1].to_i
            roles_hash = app_roles_hash(a.roles)
            roles_hash[role_id].values.join(", ")
          else
            case c
            when "dev_department"
              Dept.find_by(id: a.dev_department).try(:orgNm)
            when "apks"
              a.apk_bases.map(&:name).join(", ")
            when "production_type"
              case a.production_type.to_i
              when 1
                "APK"
              when 4
                "预装应用"
              end
            when "has_adapter_report"
              case a.has_adapter_report.to_s
              when '1', 'true'
                '是'
              when '0', 'false'
                '否'
              else
                ''
              end
            else
              a.send(c)
            end
          end
        }), style: body
      end
    end

    package.to_stream.read
  end
end
