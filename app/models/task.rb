class Task < ActiveRecord::Base
  include AASM

  has_many :alter_records, :as => :alter_for, :dependent => :destroy, :inverse_of => :alter_for
  belongs_to :container, :polymorphic => true
  belongs_to :author, :class_name => "User", foreign_key: "author_id"
  belongs_to :assigned_to, :class_name => "User", foreign_key: "assigned_to_id"

  validates :name, :assigned_to_id, presence: true
  validates :description, :start_date, :due_date, presence: true, if: :personal_task?
  validates_length_of :name, :maximum => 50, if: :personal_task?
  # validates_inclusion_of :status, :in => TASK_STATUS.map{|k,v| v[0]}.flatten
  
  after_save :create_alter, :empty_notes, :build_issue_to_merge_job, :send_notification
  before_save :update_actual_date

  acts_as_attachable :view_permission => :view_files,
                     :edit_permission => :manage_files,
                     :delete_permission => :manage_files

  TASK_STATUS = {
      :submitted => [1, "提交"],      # 提交
      :opened => [2, "打开"],         # 打开
      :reopened => [3, "重打开"],     # 重打开
      :finished => [4, "完成"],       # 完成
      :confirmed => [5, "已确认"],    # 已确认
      :closed => [6, "关闭"],         # 关闭
      :refused => [7, "拒绝"],        # 拒绝
      :assigned => [9, "分配"],
      :designed => [10, "设计完成"],
      :merged => [11, "已合入"],       # 已合入
      :auditing => [12, "待审核"],     # 待审核
      :confirming => [13, "待确认"],   # 待确认
      :merging => [14, "待合入"],      # 待合入
      :unmerged => [15, "合入失败"],    # 合入失败
      :executing => [16, "执行中"],
      :fullmerged => [17, "完全合入"],    # 完全合入
      :update_failed => [18, "分支升级失败"],
      :update_success => [19, "分支升级成功"],
      :merge_failed => [20, "主干合入失败"],
      :merge_success => [21, "主干合入成功"],
      :push_failed => [22, "主干推送失败"],
      :push_success => [23, "主干推送成功"],
      :approving => [24, "待评审"],
      :agreed => [25, "同意"]
  }

  enum status: TASK_STATUS.collect { |key, value| [key, value[0]] }.to_h

  # Define Workflow
  aasm :column => :status, :enum => true, :logger => Rails.logger do
    state :submitted, :initial => true
    state :opened, :reopened, :finished, :confirmed, :refused, :closed, :assigned, :designed, :executing
    state :update_failed, :update_success, :merge_failed, :merge_success, :push_failed, :push_success, :approving, :agreed

    event :flow_to_assigned_to, :guards => [:flow_assigned_to?] do
      transitions :from => [:submitted, :reopened], :to => :opened
      transitions :from => :opened, :to => [:refused, :finished]
    end

    event :flow_to_check_user do
      transitions :from => [:refused, :finished], :to => :confirmed
    end

    event :flow_to_spm do
      transitions :from => :confirmed, :to => [:closed, :reopened]
    end

    event :do_refuse do
      transitions :from => :opened, :to => :refused
    end

    event :do_open do
      transitions :from => [:submitted, :reopened], :to => :opened
    end

    event :do_reopen do
      transitions :from => [:refused, :confirmed], :to => :reopened
    end

    event :do_finish do
      transitions :from => [:opened, :reopened], :to => :finished
    end

    event :do_confirm do
      transitions :from => [:finished, :refused], :to => :confirmed
    end

    event :do_close do
      transitions :from => :confirmed, :to => [:closed, :reopened]
    end
  end

  # Check if can flow to assigned to
  def flow_assigned_to?
    self.assigned_to_id.present?
  end

  def allowed_statuses
    aasm.states(:permitted => true).map(&:name)
  end
  
  #options for issue_to_special_test_task
  def update_task_and_result(task, result, attachments)
    @task = self
    container.save_attachments(attachments) if attachments.present?
    container.init_alter
    if container.update(result)
      if is_design?
        if task[:status] == "10" 
          @task.assigned_to_id = container.assigned_to_id 
          @task.is_read = false
        end
        @task.status = task[:status].to_i
        @task.save
      elsif is_assign?
        @task.status = task[:status].to_i
        @task.due_date = Time.now
        @task.save
      end
      status = true
      messages = "操作成功!"
    else
      status = false
      messages = container.errors.full_messages
    end
    return status, messages
  end

  # change issue_to_special_test_result assigned_to_id 
  def reassigned_to(assigned_to_id)
    @task = self
    case @task.container_type
    when "Library"
      @task.init_alter
      container.init_alter
      container.all_libraries.update_all(user_id: assigned_to_id)
      @task.update(assigned_to_id: assigned_to_id, is_read: false)
      container.send_notification
    else
      container.init_alter
      container.update(assigned_to_id: assigned_to_id)
      @task.update(assigned_to_id: assigned_to_id, is_read: false)
    end
  end

  def is_design?
    assigned? &&  User.current.id == assigned_to_id
  end

  def is_assign?
    designed? &&  User.current.id == assigned_to_id
  end

  #options for personal tasks
  def update_personal_task(task, attachments)
    @task = self
    @task.save_attachments(attachments) if attachments.present?
    @task.init_alter
    if @task.update(task)
      status = true
      messages = "操作成功!"
    else
      status = false
      messages = @task.errors.full_messages
    end

    return status, messages
  end

  def update_actual_date
    if container_type == "PersonalTask"
      if created_at == updated_at && !submitted? && !new_record?
        self.update_columns(actual_start_date: Time.now)
      elsif closed?
        self.update_columns(actual_due_date: Time.now)
      end
    end
  end

  def assigned_to_edit?
    %w(submitted reopened executing).include?(status) && (author_id != assigned_to_id)
  end

  def author_edit?
    %w(finished refused).include?(status) || new_record? || (author_id == assigned_to_id)
  end

  def personal_task?
    container_type == "PersonalTask"
  end

  def delete_attachment?(attachment)
    # if assigned_to_id == author_id
    #   !closed?
    # else
    #   if author_edit?
    #     User.current.id != assigned_to_id && attachment.author_id == User.current.id
    #   elsif assigned_to_edit?
    #     User.current.id != author_id && attachment.author_id == User.current.id
    #   end
    # end
    personal_task_edit? && attachment.author_id == User.current.id
  end

  def personal_task_edit?
    if assigned_to_id != author_id
      (assigned_to_edit? && User.current.id == assigned_to_id) || (author_edit? && User.current.id == author_id)
    else
      !closed?
    end
  end

  def init_alter(notes = "")
    @current_alter ||= AlterRecord.new(:alter_for => self, :user => User.current)
  end

  # Returns the current journal or nil if it's not initialized
  def current_alter
    @current_alter
  end

  def create_alter
    if current_alter && %w(PersonalTask Library PatchVersion LibraryFile).include?(container_type)
      current_alter.save
    end
  end

  def altered_attribute_names
    names = Task.column_names - %w(id container_id container_type author_id created_at updated_at actual_start_date actual_due_date is_read)
  end

  def visible_alter_records(prop_key = nil)
    if prop_key.present?
      AlterRecord.includes(:details).where(alter_for_id: self.id, alter_record_details: {prop_key: prop_key})
    else
      AlterRecord.includes(:details).where(alter_for_id: self.id).where.not(alter_record_details: {prop_key: "notes"})
    end
  end

  def empty_notes
     self.update_columns(notes: nil) if container_type == "PersonalTask"
  end

  def issue_to_approve
    IssueToApproveMerge.find_by_issue_type_and_id(IssueToApproveMerge::ISSUE_TYPE[0], self.container_id)
  end

  def issue_to_merge
    IssueToApproveMerge.find_by_issue_type_and_id(IssueToApproveMerge::ISSUE_TYPE[1], self.container_id)
  end

  def build_issue_to_merge_job
    if self.status == :merging && self.container_type == IssueToApproveMerge::ISSUE_TYPE[1]
      JSON.parse(self.issue_to_merge.repo_request_ids).each { |repo_request_id|
        repo = RepoRequest.find(repo_request_id)
        build_params = {:server_ip => repo.server_ip, :repository_name => repo.repo_name, :branch_name => repo.branch, :origin_repo_name => "", :base_commit_id => self.issue_to_merge.commit_id}
        IssueToMergeJob.perform_later(self, build_params)
      }

      self.issue_to_merge.reload
      merged_repos = JSON.parse(self.issue_to_merge.repo_request_ids)
      send_notification_if_merge_fail if merged_repos.find{|repo| repo["merge_result"] != "SUCCESS"}.present?
      send_notification_if_all_success if merged_repos.find{|repo| repo["merge_result"] != "SUCCESS"}.nil?
    end
  end

  def send_notification
    if submitted? && container_type == "PersonalTask" && author_id != assigned_to_id
      send_personal_task_notification 
    end
  end

  def update_library_task(task)
    @task = self
    last_status_was = @task.status

    @task.init_alter
    if @task.update(task)
      if %w(update_success merge_success push_success).include?(@task.status) && last_status_was != @task.status
        container.init_alter
        container.update(status: task[:status])
        container.all_libraries.update_all(status: task[:status])
        notes, value = container.status_text("Patch 人为合入记录")
        @patch_record = AlterRecord.new(alter_for_id: container.container_id, alter_for_type: container.container_type, notes: notes)
        @patch_record.details.build(prop_key: "Jenkins #{container.status} History: {id: #{container.id}, status: #{container.status}, status_was: #{container.status_was}}",
                                    value: value)
        @patch_record.save
        container.check_all_libraries
      end
      @task.update_columns(notes: nil) if task[:notes].present?
      status = true
      messages = "操作成功!"
    else
      status = false
      messages = @task.errors.full_messages
    end

    return status, messages
  end

  def update_apk_base_task(task)
    @task = self
    @task.init_alter
    if @task.update(task)
      if @task.status == 'agreed'
        @desc = JSON.parse(@task.description)
        apk_base_params = @desc["content"]["apk_base"]
        case @desc["method"]
        when "add"
          case container.app_category
          when 1
            container.assign_attributes(apk_base_params)
            status = container.save
          when 10
            container.assign_attributes({android_platform: apk_base_params["android_platform"]})
            status = container.save
          end
        when "modify"
          case container.app_category
          when 1
            if @desc["change"]["integrated"] && @desc["change"]["integrated"]["new"] == "false"
              container.clear_base_info
              container.assign_attributes(apk_base_params)
              status = container.save
            else
              container.assign_attributes(apk_base_params)
              status = container.save
            end
          when 10
            container.assign_attributes({android_platform: apk_base_params["android_platform"]})
            status = container.save
          end
        when "delete"
          status = container.do_delete
        end
      else
        status = true
      end
      messages = container.errors.full_messages
    else
      status = false
      messages = @task.errors.full_messages
    end

    return status, messages
  end

  def update_patch_version_task(version, task)
    @task = self

    Task.transaction do 
      @task.init_alter
      if @task.update(task)
        @task.update_columns(notes: nil) if task[:notes].present?
      end
      container.confirm_result(version, id)
    end

    return true, []
  end

  def update_library_update_task(container_params=nil, task)
    @task = self

    Task.transaction do 
      @task.init_alter
      if @task.update(task)
        @task.update_columns(notes: nil) if task[:notes].present?
      end
      case container_type
      when 'LibraryFile'
        container.update_file_infos(container_params[:status])
      when 'Library'
        container.update_library_infos(task[:status])
      end
    end

    return true, []
  end

  def update_library_merge_task(task)
    @task = self

    Task.transaction do 
      @task.init_alter
      if @task.update(task)
        @task.update_columns(notes: nil) if task[:notes].present?
      end
      container.update_library_infos(task[:status])
    end

    return true, []
  end

  def build_apk_base_info(project=nil)
    apk_base_info = {}
    if container_type == "ApkBase"
      @apk = container
      @description = JSON.parse(description)
      if @apk.app_category == 1
        if @description["change"].has_key?("integrated")
          @final_integrated = @description["change"]["integrated"]["new"]
          @has_base_info =  @final_integrated == "true" ? false : true
        else
          @final_integrated = @apk.integrated.to_s
          @has_base_info =  @final_integrated == "true" ? "true" : "false"
        end
      else
        @has_base_info = true
      end

      if container.app_category.to_i == 1
        @project = project.present? ? project : container.project_apk.project
        apk_base_info[l(:project_apk_project_id)] = @project.name
        apk_base_info["APP-SPM"] = @project.users_of_role(27).map(&:firstname).join(",")
        apk_base_info["APP-Master"] = @project.users_of_role(29).map(&:firstname).join(",")
      end
      @apk_base_info = @has_base_info ? @description["content"]["apk_base_old"] : @description["content"]["apk_base"]

      apk_base_info[l(:apk_base_name)] = @apk.name
      apk_base_info[l(:apk_base_android_platform)] = self.name
      apk_base_info[l(:apk_base_integrated)] = @final_integrated.present? ? ( @final_integrated == "false"? l(:general_text_no) : l(:general_text_yes)) : "" if @apk.app_category == 1
      apk_base_info[l(:apk_base_desktop_name)] = @apk_base_info["desktop_name"]
      apk_base_info[l(:apk_base_cn_name)] = @apk_base_info["cn_name"]
      apk_base_info[l(:apk_base_cn_description)] = @apk_base_info["cn_description"]
      apk_base_info[l(:apk_base_developer)] = @apk_base_info["developer"]
      apk_base_info[l(:apk_base_package_name)] = @apk_base_info["package_name"]
      apk_base_info[l(:apk_base_category_id)] = ::ApkBaseCategory.find(@apk_base_info["category_id"]).try(:name)
      apk_base_info[l(:apk_base_removable)] = @apk_base_info["removable"].present? ? (@apk_base_info["removable"] == "1" ? "是" : "否") : ""
      apk_base_info[l(:apk_base_desktop_icon)] = @apk_base_info["desktop_icon"].to_s == "false" ? "否" : (@apk_base_info["desktop_icon"].to_s == "true" ? "是" : "")
      apk_base_info[l(:apk_base_app_category)] = l("apk_base_app_category_#{ApkBase::APK_BASE_APP_CATEGORY.key(@apk.app_category.to_i).to_s}")
      apk_base_info[l(:spec_note)] = l("apk_base_label_#{@description['method']}") + apk_base_info[l(:apk_base_app_category)]
    end
    return apk_base_info
  end

  scope :unfinished, lambda { where("status in (#{TASK_STATUS[:submitted][0]},#{TASK_STATUS[:opened][0]},#{TASK_STATUS[:reopened][0]},#{TASK_STATUS[:refused][0]}.#{TASK_STATUS[:confirming]})") }
  scope :finished, lambda { where("status in (#{TASK_STATUS[:finished][0]},#{TASK_STATUS[:confirmed][0]},#{TASK_STATUS[:closed][0]})") }

  scope :assigned_to_me, lambda { |assigned_to_id, sql, order|
    select("tasks.id task_id,projects.name project_name,plans.name plan_name,tasks.name task_name,tasks.status status_id,plan_start_date,plan_due_date,start_date,due_date,
            plans.assigned_to_id,plans.check_user_id,plans.author_id,users.firstname assigned_to,case when plans.assigned_to_id = '#{assigned_to_id}' then plans.assigned_to_note
            when plans.check_user_id = '#{assigned_to_id}' then plans.checker_note when plans.author_id = '#{assigned_to_id}' then plans.author_note else '' end note,#{convert_status}").
    joins("inner join plans on plans.id = tasks.container_id and container_type = 'Plan'
           inner join projects on projects.id = plans.project_id
           left join users on users.id = tasks.assigned_to_id").
    where("tasks.assigned_to_id = #{assigned_to_id} and #{sql.blank? ? '1=1' : sql}").
    order("#{order || 'tasks.updated_at desc'}")
  }

  scope :convert_status, -> { "case tasks.status
        when 1 then '提交' when 2 then '打开' when 3 then '重打开'
        when 4 then '完成' when 5 then '已确认' when 6 then '关闭'
        when 7 then '拒绝' when 8 then '确认中' when 9 then '分配'
        when 10 then '设计完成' when 16 then '执行中' when 18 then '升级失败' 
        when 19 then '升级成功' when 20 then '合入失败' when 21 then '合入成功' 
        when 22 then '推送失败' when 23 then '推送成功' when 24 then '待评审'
        when 25 then '同意'  end status_name" }
  scope :issue_to_special_test_tasks, lambda{
    select("tasks.id AS task_id, CONCAT(projects.name, '-R-', tests.id) AS test_id, results.id AS result_id, tasks.name AS task_name, designers.firstname AS designer, 
            assigners.firstname AS assigner, tasks.created_at AS created_at, projects.identifier AS project_identifier, #{convert_isread}, #{convert_isread}")
    .joins("INNER JOIN issue_to_special_test_results AS results ON results.id = tasks.container_id AND container_type = 'IssueToSpecialTestResult'
            LEFT JOIN issue_to_special_tests AS tests ON tests.id = results.special_test_id
            LEFT JOIN projects ON projects.id = tests.project_id
            LEFT JOIN users AS designers ON designers.id = results.designer_id
            LEFT JOIN users AS assigners ON assigners.id = results.assigned_to_id")
    .where("container_type = 'IssueToSpecialTestResult' AND tasks.status IN (4, 9, 10) AND (results.assigned_to_id = #{User.current.id} OR results.designer_id = #{User.current.id})")
    .reorder("tasks.created_at desc")
  }
  scope :personal_tasks, lambda{ |sql|
    select("tasks.id, name, assigners.firstname as firstname, authors.firstname as author_name, start_date, due_date, actual_start_date, actual_due_date,#{convert_status}, #{convert_isread}")
    .joins("LEFT JOIN users as assigners ON assigners.id = tasks.assigned_to_id
            LEFT JOIN users as authors ON authors.id = tasks.author_id")
    .where("container_type = 'PersonalTask' AND #{sql}")
    .reorder("tasks.created_at desc")
  }
  scope :libraries, lambda{
    select("tasks.id, tasks.name, assigners.firstname as firstname, lib.name as lib_name, lib.path as lib_path, tasks.created_at AS created_at, due_date, actual_due_date, #{convert_status}, #{convert_isread}")
    .joins("INNER JOIN users as assigners ON assigners.id = tasks.assigned_to_id
            INNER JOIN libraries as lib ON lib.id = tasks.container_id AND tasks.container_type = 'Library'")
    .where("tasks.assigned_to_id = #{User.current.id}")
    .reorder("tasks.created_at desc")
  }
  scope :apk_bases, lambda{
    select("tasks.id, tasks.name platform, ab.name apk_name, projects.name app_name, authors.firstname as firstname, tasks.notes as notes, tasks.created_at AS created_at, #{convert_status}, #{convert_isread},
            case ab.app_category when 1 then 'APK' when 10 then 'Google原生应用' else '预装应用' end app_category ")
    .joins("INNER JOIN users as authors ON authors.id = tasks.author_id
            INNER JOIN apk_bases as ab ON ab.id = tasks.container_id AND tasks.container_type = 'ApkBase'
            LEFT JOIN project_apks as pa ON pa.apk_base_id = ab.id 
            LEFT JOIN projects ON projects.id = pa.project_id")
    .where("tasks.assigned_to_id = #{User.current.id}")
    .reorder("tasks.created_at desc")
  }
  scope :patch_versions, lambda{
    select("tasks.id, patches.patch_no, pv.name, pv.version_url, pv.version_log, pv.due_at, #{convert_isread}, pv.result,
            case pv.status when 'failed' then '失败' else '成功' end pv_status,
            case pv.category when 'precompile' then '预编译版本' else '验证版本' end pv_category")
    .joins("INNER JOIN users as assigners ON assigners.id = tasks.assigned_to_id
            INNER JOIN patch_versions as pv ON pv.id = tasks.container_id AND tasks.container_type = 'PatchVersion'
            LEFT JOIN patches ON patches.id = pv.patch_id")
    .where("tasks.assigned_to_id = #{User.current.id}")
    .reorder("tasks.created_at desc")
  }
  scope :update_libraries, lambda{
    select("tasks.id, patches.patch_no, tasks.name, assigners.firstname as firstname, lib.name as lib_name, lib.path as lib_path, 
            tasks.created_at AS created_at, patches.due_at, '' file, '' file_status, '' conflict_type, #{convert_status}, #{convert_isread}")
    .joins("INNER JOIN users as assigners ON assigners.id = tasks.assigned_to_id
            INNER JOIN libraries as lib ON lib.id = tasks.container_id AND tasks.container_type = 'Library'
            LEFT JOIN patches ON lib.container_id = patches.id AND lib.container_type = 'Patch'")
    .where("tasks.assigned_to_id = #{User.current.id} AND tasks.status in (18, 19)")
    .reorder("tasks.created_at desc")
  }
  scope :library_files, lambda{
    select("tasks.id, patches.patch_no, tasks.name, assigners.firstname as firstname, lib.name as lib_name, lib.path as lib_path, 
            tasks.created_at AS created_at, patches.due_at, library_files.name file, library_files.conflict_type, #{convert_status}, #{convert_isread},
            case library_files.status when 'success' then '成功' else '失败' end file_status")
    .joins("INNER JOIN users as assigners ON assigners.id = tasks.assigned_to_id
            INNER JOIN library_files ON library_files.id = tasks.container_id AND tasks.container_type = 'LibraryFile'
            LEFT JOIN libraries as lib ON lib.id = library_files.library_id
            LEFT JOIN patches ON lib.container_id = patches.id AND lib.container_type = 'Patch'")
    .where("tasks.assigned_to_id = #{User.current.id} AND tasks.status in (18, 19)")
    .reorder("tasks.created_at desc")
  }
  scope :merge_libraries, lambda{
    select("tasks.id, patches.patch_no, tasks.name, assigners.firstname as firstname, lib.name as lib_name, lib.path as lib_path, tasks.created_at AS created_at, patches.due_at, #{convert_status}, #{convert_isread}")
    .joins("INNER JOIN users as assigners ON assigners.id = tasks.assigned_to_id
            INNER JOIN libraries as lib ON lib.id = tasks.container_id AND tasks.container_type = 'Library'
            LEFT JOIN patches ON lib.container_id = patches.id AND lib.container_type = 'Patch'")
    .where("tasks.assigned_to_id = #{User.current.id} AND tasks.status in (20, 21, 22, 23)")
    .reorder("tasks.created_at desc")
  }
  scope :convert_isread, -> {"CASE tasks.container_type
                              WHEN 'PersonalTask' THEN IF(tasks.author_id = #{User.current.id}, true, tasks.is_read)
                              WHEN 'IssueToSpecialTestResult' THEN IF((tasks.assigned_to_id = #{User.current.id} AND tasks.is_read = 0), false, true) 
                              ELSE tasks.is_read END is_read "}
  private

  def send_notification_if_merge_fail
    receivers = []
    self.issue_to_merge.issue.project.users_of_role(Role.find_by_name("软件负责人").id).each { |user| receivers << user }

    send_merge_notification(receivers, {:success => false})
  end

  def send_notification_if_all_success
    receivers = [self.issue_to_merge.issue.assigned_to, self.issue_to_merge.issue.assigned_to.dept_leader]
    notification_roles = ["SPM", "软件负责人", "测试负责人"]
    Role.where(:name => notification_roles).each { |role|
      self.issue_to_merge.issue.project.users_of_role(role.id).each { |user| receivers << user }
    }

    send_merge_notification(receivers, {:success => true})
  end

  def send_merge_notification(receivers, options = {})
    options.merge!({:issue_to_merge => self.issue_to_merge})

    begin
      Mailer.issue_to_merged_notification(receivers, options).deliver
    rescue
      receivers.each do |receiver|
        begin
          Mailer.issue_to_merged_notification(receiver, options).deliver
        rescue
          next
        end
      end
    end
  end

  def send_personal_task_notification
    if submitted? && author_id != assigned_to_id && container_type == "PersonalTask"
      options = {:task => self}
      receivers = [assigned_to]

      begin
        Mailer.personal_task_notification(receivers, options).deliver
      rescue
        receivers.each do |receiver|
          begin
            Mailer.personal_task_notification(receiver, options).deliver
          rescue
            next
          end
        end
      end
    end
  end
end
