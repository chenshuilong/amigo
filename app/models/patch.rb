class Patch < ActiveRecord::Base
  has_many :libraries, :as => :container, :dependent => :destroy
  has_many :alter_records, :as => :alter_for, :dependent => :destroy, :inverse_of => :alter_for
  has_many :patch_versions
  belongs_to :author, :class_name => 'User'

  serialize :init_command, Hash
  serialize :jenkins_url, Hash
  serialize :object_ids, Array
  serialize :object_names, Hash

  validates :patch_no, :patch_type, :author_id, :status, :init_command, :notes, :due_at, :object_ids, presence: true
  validates :proprietary_tag, presence: true, if: "patch_type == 2"

  PATCH_STATUS = %w(doing success failed).freeze
  PATCH_PATCH_TYPE = {:mtk => 1, :qc => 2}.freeze

  JOB_NAME = {:job1 => "job_1",
              :job2 => "job_2",
              :job3 => "job_3",
              :job_precompile => "job_precompile",
              :job_postcompile => "job_precompile"}.freeze

  scope :unfinish_count, lambda { |patch_type| where("patch_type = #{patch_type} AND status = 1").count}

  def self.generate_patchno(patch_type)
    @last = all.where(patch_type: patch_type.to_i).reorder('patch_no desc').first
    last_no = @last.present? ? @last.patch_no.split('-').last.to_i : 0
    current_patch_no =  Patch::PATCH_PATCH_TYPE.key(patch_type.to_i).to_s.upcase + '-Patch-' + (last_no+1).to_s
    return current_patch_no
  end

  def init_alter(notes = "")
    @current_alter ||= AlterRecord.new(:alter_for => self, :user => User.current)
  end

  # Returns the current journal or nil if it's not initialized
  def current_alter
    @current_alter
  end

  def create_alter
    if current_alter
      current_alter.save
    end
  end

  def altered_attribute_names
    #names = Patch.column_names - %w(id created_at updated_at)
    names  = []
  end

  def do_jenkins_job(category, unlock=nil)
    if status == "doing"
      begin
        patch_params = build_api_params(category, unlock)
        case category 
        when "unlock"
          job_name = "auto_unlock_submit_access_for_all_project"
        when "task_001", "task_002", "task_003"
          job_name = "auto_update_mtk_or_qc_mirror_code_#{category}_new"
        when "precompile", "postcompile"
          job_name = "auto_update_mtk_or_qc_mirror_code_#{category}"
        end
        @jenkins = Api::Jenkins.new
        result = @jenkins.build_branch(job_name, patch_params) 
        puts "[#{Time.now}] Do_jenkins_#{category}_job result: #{result}"
      rescue => e 
        puts "Error: #{e}"
      end
    end
  end

  def build_api_params(category, unlock=nil)
    api_params = {}
    repo_type = Patch::PATCH_PATCH_TYPE.key(patch_type).to_s.downcase
    api_params[:server_ip] = "19.9.0.152" #19.9.0.152
    api_params[:repository_name] = "android_#{repo_type}"
    case category
    when "unlock"
      api_params[:branch_name] = unlock[:unlock]
      api_params[:amige_id] = id
    when "task_001"
      api_params[:manifest_url] = init_command[:manifest_url]
      api_params[:manifest_branch] = init_command[:manifest_branch]
      api_params[:new_xml_filename] = init_command[:manifest_xml] if init_command[:manifest_xml].present?
      api_params[:repo_url] = init_command[:repo_url] if init_command[:repo_url].present?
      api_params[:origin_code_path] = "/home/review_site/git/#{api_params[:repository_name]}"
      api_params[:branch_name] = "origin_master"
      api_params[:manifest_path] = "/home/android/jenkins_update_multirepo_code_root_path/#{api_params[:repository_name]}"
      api_params[:origin_proprietary_tag] = proprietary_tag.to_s
      api_params[:product_name] = object_names.values.join(",")
      api_params[:amige_id] = id
    when "task_002", "precompile", "postcompile"
      api_params[:product_name] = object_names.values.join(",")
      api_params[:amige_id] = id
    when "task_003"
      api_params[:amige_id] = id
    end
    return api_params
  end

  def validate_init_command
    errors.add(:manifest_url, "manifest_url 不能为空字符") if init_command[:manifest_url].blank?
    errors.add(:manifest_branch, "manifest_branch 不能为空字符") if init_command[:manifest_branch].blank?
    errors.add(:manifest_xml, "manifest_xml 不能为空字符") if init_command[:manifest_xml].blank?
    result = errors.present?

    return result
  end

  def update_jenkins_url(params, unlock=nil)
    @patch = self
    key = params[:jenkins_url].keys[0].to_s
    @jenkins_url = {}
    @jenkins_url["task1"] = []
    @jenkins_url["task2"] = []
    @jenkins_url["task3"] = []
    @jenkins_url["taskprecompile"] = []
    @jenkins_url["taskpostcompile"] = []
    %w(task1 task2 task3 taskprecompile taskpostcompile).each do |i|
      if i == key
        @task_url = @patch.jenkins_url[key].present? ? @patch.jenkins_url[key] : []
        @jenkins_url[i] = @task_url + (params[:jenkins_url].collect{|k, v| {url: v, start_at: Time.now}})
      else
        @jenkins_url[i] = @patch.jenkins_url[i] if @patch.jenkins_url[i].present?
      end
    end
    @patch.update_columns(jenkins_url: @jenkins_url)
  end

  #----------- JENKINS REWRITE METHODs start -----------#
  def do_rewrite_jenkins(params)
    result = false

    if params.has_key?(:operation)
      case params[:operation]
      when 'initial'
        result = do_initial(params)
      when 'precompile', 'postcompile'
        result = do_compile(params)
      when 'do_update'
        result = do_update(params)
      when 'do_merge', 'do_push'
        result = do_merge_or_push(params)
      end
    end

    return result 
  end

  def do_closed(params)
    patch_params = {}
    patch_params[:status] = params[:result]
    patch_params[:reason] = params[:reason]  if params[:reason].present?
    patch_params[:actual_due_at] = Time.now 

    ##回写成功/失败信息
    #
    #
    Patch.transaction do 
      self.update_columns(patch_params) if patch_params.present?
      notes = self.status == "success" ? "Patch 升级任务完成！" : "Patch升级任务失败！"
      record = AlterRecord.new(alter_for: self, notes: notes.to_s)
      record.details.build(prop_key: "reason", value: reason.to_s) if self.status == "failed"
      record.save
    end

    return true
  end

  #获取增、删、改仓库及文件清单
  #
  #仓库责任人默认为: 李世鹏(user_id=574)
  #
  #
  def do_initial(params)
    if params.has_key?(:libraries).present?
      libraries = params[:libraries]
        if libraries.present?
          libraries.each do |lib|
            pl = Library.find_by(container_id: id, container_type: self.class.name, name: lib[:name], path: lib[:path], uniq_key: nil)
            next if pl.present?
            pl_uniq_key = []
            if lib[:files].present?
              $i = 0
              $total_files = lib[:files].count/500 + (lib[:files].count%500 == 0 ? 0 : 1)
              $start = 0
              $end = 499  
              while $i < $total_files  do
                new_lib_params = {}
                new_lib_params[:container_id] = id
                new_lib_params[:container_type] = self.class.name
                new_lib_params[:name] = lib[:name]
                new_lib_params[:path] = lib[:path]
                new_lib_params[:status] = lib[:status]
                new_lib_params[:change_type] = lib[:type]
                new_lib_params[:files] = lib[:files][$start..$end].to_json
                new_lib_params[:user_id] = 574
                new_lib_params[:uniq_key] = pl_uniq_key[0] if pl_uniq_key.present?
                new_lib = ::Library.create(new_lib_params)
                pl_uniq_key << new_lib.id  unless pl_uniq_key.present?
                $i +=1
                $start += 500
                $end   += 500
              end
            else
              @pls << ::Library.create(container_id: id, 
                                 container_type: self.class.name, 
                                 name: lib[:name], 
                                 path: lib[:path], 
                                 status: lib[:status], 
                                 change_type: lib[:type],
                                 user_id: 574)
            end
          end
        end
    end

    return true
  end


  #预编译/验证版本信息回写
  #
  #预编译/验证结果: {成功:项目测试负责人;失败:项目软件负责人}
  #默认负责人: {测试:田炜炜(user_id: 41); 软件:孙龙龙(user_id: 555);}
  #
  def do_compile(params)
    if params.has_key?(:precompile_versions).present? || params.has_key?(:postcompile_versions).present?
      if params.has_key?(:precompile_versions).present?
        versions = params[:precompile_versions]
      elsif  params.has_key?(:postcompile_versions).present?
        versions = params[:postcompile_versions]
      end

      if versions.present?
        versions.each do |v|
          pv = patch_versions.where(category: v[:category]).where(name: v[:name])
          next if pv.present?
          v_object_name = v[:product]
          v_object_id = object_names.key(v_object_name)
          @project = Spec.find_by(id: v_object_id).project
          @project_software = @project.users_of_role(11).first
          @project_test = @project.users_of_role(15).first
          @software_manager = @project_software.present? ? @project_software : User.find(555)
          @test_manager = @project_test.present? ? @project_test : User.find(41)
          #预编译/验证版本历史记录
          Patch.transaction do 
            result = v[:status] == "success" ? nil : 'NG'
            user = v[:status] == "success" ? @test_manager : @software_manager
            role_type = v[:status] == "success" ? 'test' : 'software'
            new_pv = PatchVersion.create(patch_id: id, category: v[:category], name: v[:name], version_url: v[:url], version_log: v[:log], status: v[:status], 
                                      software_manager_id: @software_manager.id, test_manager_id: @test_manager.id, due_at: Time.now, result: result,
                                      object_id: v_object_id, object_name: v_object_name, user_id: user.id, role_type: role_type)
            notes = "Patch "+ l("patch_jenkins_task#{v[:category]}") + " #{v[:name]} 编译" + l("patch_label_#{v[:status]}")
            AlterRecord.create(alter_for: self, notes: notes)
            Task.create(container: new_pv, name: notes, assigned_to_id: user.id)
            unlock = params[:operation] == "precompile" ? "gionee_master" : "gionee_update_master"
            do_jenkins_job("unlock", unlock: unlock) if v[:status] == "failed"
          end
        end
      end
    end

    return true
  end

  #失败仓库清单及仓库冲突文件回写
  #
  #仓库责任人为李世鹏;
  #冲突文件责任人为文件最后修改人，jenkins回写最后修改人的email，阿米哥先通过email找到相应用户，找不到则指给李世鹏
  #
  def do_update(params)
    if params.has_key?(:update_failed_libraries)
      faileds = params[:update_failed_libraries]

      if faileds.present?
        @record = AlterRecord.new(alter_for: self, notes: "gionee_update 升级分支失败")
        faileds.each do |lib|
          @uniq_pl = libraries.find_by(name: lib[:name], path: lib[:path], uniq_key: nil)
          next if @uniq_pl.blank?
          @uniq_pl.all_libraries.update_all(status: lib[:status])
          files = lib[:failed_files]
          if files.present?
            files.each do |file|
              Patch.transaction do 
                email_user_id = EmailAddress.find_by(address: file[:email]).try(:user_id)
                user_id = email_user_id.present? ? email_user_id : 574
                new_lf = @uniq_pl.library_files.find_by(name: file[:name])
                if new_lf.blank?
                  new_lf = LibraryFile.create(library_id: @uniq_pl.id, name: file[:name], conflict_type: file[:conflict_type], status: 'failed', email: file[:email], user_id: user_id)
                else
                  next if new_lf.status == "failed" && new_lf.conflict_type == file[:conflict_type]
                  new_lf.update(conflict_type: file[:conflict_type], status: 'failed', email: file[:email], user_id: user_id)
                end
                value = "Name: #{@uniq_pl.name}, Path: #{@uniq_pl.path}, File: #{file[:name]}, 责任人#{User.find_by(id: user_id).try(:firstname)}"
                @record.details << AlterRecordDetail.new(prop_key: "仓库(id: #{@uniq_pl.id})升级失败,含冲突文件", value: value)
                Task.create(container: new_lf, name: value, assigned_to_id: user_id, status: lib[:status])
              end
            end
          else
            Patch.transaction do 
              value = "Name: #{@uniq_pl.name}, Path: #{@uniq_pl.path}, 责任人#{@uniq_pl.user.firstname}"
              @record.details << AlterRecordDetail.new(prop_key: "仓库(id: #{@uniq_pl.id})升级失败,无冲突文件", value: value)
              @task = @uniq_pl.task
              if @uniq_pl.task.present?
                @task.update(status: lib[:status], assigned_to_id: @uniq_pl.user_id, is_read: false)
              else
                Task.create(container: @uniq_pl, name: value, status: lib[:status], assigned_to_id: @uniq_pl.user_id)
              end
            end
          end
        end

        @record.save if @record.details.present?
      end
    end

    return true
  end

  def do_merge_or_push(params)
    if params.has_key?(:failed_libraries)
      faileds = params[:failed_libraries]
      if faileds.present?
        @record = AlterRecord.new(alter_for: self, notes: "gionee_update #{params[:operation] == "do_merge" ? '主干合并失败' : '主干推送失败'}")
        faileds.each do |lib|
          @uniq_pl = libraries.find_by(name: lib[:name], path: lib[:path], uniq_key: nil)

          next if @uniq_pl.blank?
          Patch.transaction do 
            @uniq_pl.all_libraries.update_all(status: lib[:status])
            value = "Name: #{@uniq_pl.name}, Path: #{@uniq_pl.path}, 责任人#{@uniq_pl.user.firstname}"
            @record.details << AlterRecordDetail.new(value: value)
            @task = @uniq_pl.task

            if @task.present?
              @task.update(status: lib[:status], assigned_to_id: @uniq_pl.user_id, is_read: false)
            else
              Task.create(container: @uniq_pl, name: value, status: lib[:status], assigned_to_id: @uniq_pl.user_id)
            end
          end
        end
        @record.save if @record.details.present?
      end
    end

    return true
  end

  #----------- JENKINS REWRITE METHODs end   -----------#
end
