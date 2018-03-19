class ApiController < ApplicationController

  include HTTParty
  include ApiHelper
  include MyHelper
  layout false

  accept_api_auth :issue_history_status, :gradle_version

  # Lingfen's demands
  def issue_history_status
    issue = Issue.find_by("id = ?", params[:id])
    if issue.nil?
      render :json => "Error. No such an issue."
    else
      render :json => status_history(issue)
    end
  end

  def depts_tree
    dept_id = params[:id].to_s[/\d+/]
    dept = Dept.find(dept_id)
    if dept
      render :json => get_dept_json(dept.children)
    else
      render :json => []
    end
  end

  def dept_users
    dept_id = params[:dept_id].to_s[/\d+/]
    user_name = params[:name]

    dept = Dept.find(dept_id) rescue nil
    dept = nil if dept && dept.id == 1
    if dept || user_name
      scope = dept.try(:all_users) || User.all
      scope = scope.where('users.id > 2').like(user_name) if user_name
      render :json => get_user_json(scope, params[:page])
    else
      render :json => []
    end
  end

  def xianxiang
    name = params[:xx_name]
    pzs = Mokuai.xianxiang.where(:reason => name).pluck(:name, :description)
    render :json => {relation: pzs.to_h, names: pzs.map(&:first)}
  end

  # LingFen's demands for get user basic info

  def user
    name   = params[:name]
    number = params[:number]
    mail   = params[:mail]
    id     = params[:id]
    mail   = "#{mail}@gionee.com" if mail.present? && mail.exclude?("@")

    scope = User.all
    scope = scope.where(:id => id) if id.present?
    scope = scope.like(name) if name.present?
    scope = scope.where(:empId => number) if number.present?
    scope = scope.joins(:email_addresses).where(:email_addresses => {:address => mail}) if mail.present?

    users = scope.count == User.all.count ? [] : scope.limit(30)
    hash = users.map do |user|
      {
          :name => user.name,
          :id => user.id,
          :global_id => user.login,
          :number => user.empId,
          :mail => user.mail,
          :dept => user.dept_name,
          :dept_id => user.dept.try(:id)
      }
    end
    render :json => hash
  end

  def virtual_version
    app_name     = params[:app_name]
    spec_name    = params[:spec_name]
    version_name = params[:version_name]
    min_version  = params[:min_version_name]
    message      = "Ok!"
    status       = 0

    if app_name
      app = Project.find(app_name)
      if app.blank?
        message = "#{app.show_by(4) ? 'Application' : 'Project'} does not exists!"
      else
        if spec_name
          spec = Spec.find(spec_name)
          if spec.blank?
            message = "Spec does not exists!"
          else
            if version_name
              if !app.show_by(4)
                app_version = app.versions.find_by_spec_id_and_name(spec.id, version_name)
                if app_version.blank?
                  app.versions << Version.new({:name => version_name, :status => 3, :compile_status => 6,
                                               :compile_type => 1, :priority => 4, :spec_id => spec.id,
                                               :repo_one_id => params[:repo_one_id] || 3, :description => "Virtual version",
                                               :repo_two_id => params[:repo_two_id] || 3, :author_id => User.current.id})
                  status = 1
                else
                  message = "Version already existed!"
                end
              else
                main_version = Version.find(version_name)
                if main_version.blank?
                  message = "Main Version not be found!"
                else
                  full_version_name = main_version.name.to_s
                  full_version_name = full_version_name.gsub(full_version_name.split('.')[-1], min_version.to_s)
                  version = Version.where(spec_id: spec_name, name: full_version_name)

                  if version.blank?
                    sql = "INSERT INTO `versions` (`project_id`, `name`, `description`, `created_on`, `updated_on`, `sharing`, `production_name`, `compile_status`, `spec_id`, `parent_id`, `unit_test`, `arm`, `repo_one_id`, `repo_two_id`, `priority`, `author_id`)
                            VALUES('#{app.id}','#{full_version_name}', 'Virtual version', '#{Time.now.to_s(:db)}', '#{Time.now.to_s(:db)}','1','none', '6', '#{spec.id}', '#{main_version.id}', 0, '32', '3', '3', '3', '#{User.current.id}');"
                    ActiveRecord::Base.connection.execute(sql)
                    status = 1
                  else
                    message = "Version already existed!"
                  end
                end
              end
            else
              message = "Parameter error!"
            end
          end
        else
          message = "Parameter error!"
        end
      end
    else
      message = "Parameter error!"
    end
    render_json message, status
  rescue => e
    render_json e.to_s
  end

  def beiyan_version
    app_name     = params[:app_name] || ""
    spec_name    = params[:spec_name] || ""
    version_name = params[:version_name] || ""
    token        = Token::BEIYAN_VERSION_TOKEN

    if token == params[:token]
      raise "Parameter error!" if app_name.to_s.strip.empty? || spec_name.to_s.strip.empty? || version_name.to_s.strip.empty?

      app = version_name.start_with?('V') ? Production.find_by_identifier(app_name) : Project.find_by_identifier(app_name)
      raise (version_name.start_with?('V') ? 'Application' : 'Project') << ' does not exists!' if app.blank?

      spec = Spec.find_by_project_id_and_name_and_deleted(app.id, spec_name, 0)
      raise "Spec does not exists!" if spec.blank?

      if version_name.start_with?('T')
        main_version_id = 'null'
      else
        main_version_name = version_name.gsub(".#{version_name.to_s.split('.')[-1]}", "")
        main_version = Version.where("project_id = #{app.id} and spec_id = #{spec.id}
                    and name like '#{main_version_name}%' and parent_id is null").order("created_on desc")
        main_version_id = main_version.blank? ? 'null' : main_version.first.id
      end

      version = Version.find_by_name_and_project_id_and_spec_id(version_name, app.id, spec.id)
      if version.blank?
        sql = "INSERT INTO `versions` (`project_id`, `name`, `description`, `sharing`, `production_name`, `compile_status`, `spec_id`, `parent_id`, `unit_test`)
           VALUES('#{app.id}', '#{version_name}', 'Beiyan version', '1', 'none', '6', '#{spec.id}', #{main_version_id}, 0);"
        ActiveRecord::Base.connection.execute(sql)
      end

      @version = Version.find_by_sql("SELECT id FROM `versions` WHERE `versions`.`name` = '#{version_name}' AND `versions`.`project_id` = #{app.id} AND `versions`.`spec_id` = #{spec.id} LIMIT 1")

      render :json => {:success => 1, :message => "Ok!", :vid => @version.first.id}
    else
      raise "Token is invalid!"
    end
  rescue => e
    render_json e.to_s
  end

  def gradle_version
    name = params[:name].squish
    if name.present?
      @gradle = GradleCategory.new(name: name, active: 1)
      if @gradle.save
        render :json => {:success => 1, :message => "Ok!"}
      else
        render :json => {:success => 0, :message => "Failed!"}
      end
    end
  rescue => e 
    render_json e.to_s
  end

  private

  def render_json(message = '', status = 0)
    render :text => {:success => status, :message => message}.to_json
  end

  def render_params_error
    render_json "Parameter error!"
  end

end


