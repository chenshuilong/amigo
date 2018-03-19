class TasksController < ApplicationController
  skip_before_action :verify_authenticity_token, :only => [:issue_to_task, :issue_to_special_test_task, :personal_task, :library_task, :apk_base_task, 
                                                           :patch_version_task, :library_update_task, :library_merge_task]
  accept_api_auth :update_special_test_task, :personal_task_create, :personal_task_update, :library_task_update
  layout 'faster_new', only: [:edit_special_test_task, :personal_task_new, :personal_task_edit, :library_task_edit, :apk_base_task_edit, 
                              :patch_version_task_edit, :library_update_task_edit, :library_merge_task_edit]

  helper :attachments
  helper :issue_to_special_test_results
  include MyHelper
  include IssueToSpecialTestResultsHelper

  def index
  end

  def edit
    task = Task.find(params[:id])
    tras_res = transition_task_by_role(task)

    render :text => {:success => 1, :message => tras_res[:message], :row => task}.to_json
  rescue => e
    render :text => {:success => 0, :message => e.to_s, :row => []}.to_json
  end

  def edit_task
    @task = Task.find(params[:tasks][:task_id])
    raise "任务不存在！" if @task.blank?
    @issue = IssueToApproveMerge.find(@task.container_id)
    @task_status = params[:tasks][:status_id].to_i

    approve_task if task_params[:issue_type] == IssueToApproveMerge::ISSUE_TYPE[0]
    merge_task if task_params[:issue_type] == IssueToApproveMerge::ISSUE_TYPE[1]

    render :text => {:success => 1, :message => l(:option_message_suc)}.to_json
  rescue => e
    render :text => {:success => 0, :message => e.to_s}.to_json
  end

  def issue_to_task
    rows = IssueToApproveMerge.assigned_to_me(User.current.id, "container_type = '#{params[:issue_type]}'", "")
    render :json => rows.to_json
  rescue => e
    render :json => []
  end

  def issue_to_special_test_task
    rows = Task.issue_to_special_test_tasks

    render :json => rows.to_json
  rescue => e
    render :json => []
  end

  #issue_to_special_test_task edit/update
  def special_test_task
    respond_to { |format| format.js }
  end

  def edit_special_test_task
    @task = Task.find(params[:id])
    @result = @task.container
    @special_test = @result.special_test
    @project = @special_test.project
    @records = AlterRecord.joins(:details).where(alter_for_id: @result.id,  alter_for_type: 'IssueToSpecialTestResult',alter_record_details: {prop_key: 'supplement'})
  end

  def update_special_test_task
    @task = Task.find(params[:id])
    @result = @task.container
    @special_test = @result.special_test

    if params[:change_assigned_to].present? 
      if params[:result][:assigned_to_id].present? && @task.assigned_to_id != params[:result][:assigned_to_id].to_i
        status, messages = @task.reassigned_to(params[:result][:assigned_to_id])
      end
    else
      status, messages = @task.update_task_and_result(special_test_task_params, result_params, params[:attachments])
    end
    
    respond_to do |format|
      if status     
        format.api  { render :text => {:success => 1, :message => l(:option_message_suc)}.to_json }      
      else
        format.api  { render :text => {:success => 0, :message => messages}.to_json }
      end
    end
  end

  # Personal Task Actions
  def personal_task
    if params[:person_type] == "author_id"
      sql = "tasks.author_id = #{User.current.id}"
    elsif params[:person_type] == "assigned_to_id"
      sql = "tasks.author_id <> #{User.current.id} AND tasks.assigned_to_id = #{User.current.id}"
    end
    rows = Task.personal_tasks(sql)

    render :json => rows.to_json
  rescue => e
    render :json => []
  end

  def personal_task_new
    @task = Task.new(container_type: "PersonalTask", status: 1)
  end

  def personal_task_create
    @task = Task.new(personal_task_params)
    @task.author_id = User.current.id
    @task.status = 1
    @task.container_type = "PersonalTask"
    @task.save_attachments(params[:attachments]) if params[:attachments].present?

    respond_to do |format|
      if @task.save  
        format.api  { render :text => {:success => 1, :message => l(:option_message_suc)}.to_json }      
      else
        format.api  { render :text => {:success => 0, :message => @task.errors.full_messages}.to_json }
      end
    end
  end

  def personal_task_edit
    @task = Task.find(params[:id])
    @notes = @task.visible_alter_records("notes")
    @historys = @task.visible_alter_records
  end

  def personal_task_update
    @task = Task.find(params[:id])
    status, messages = @task.update_personal_task(personal_task_params, params[:attachments])
    
    respond_to do |format|
      if status     
        format.api  { render :text => {:success => 1, :message => l(:option_message_suc)}.to_json }      
      else
        format.api  { render :text => {:success => 0, :message => messages}.to_json }
      end
    end
  end

  def handle
    @task = Task.find_by(:id => params[:id])
    case @task.container_type
    when 'PersonalTask'
      @task.update(is_read: true) if !@task.is_read && @task.author_id != User.current.id 
    when 'IssueToSpecialTestResult'
      @task.update(is_read: true) if !@task.is_read && @task.assigned_to_id == User.current.id
    when 'IssueToApprove', 'IssueToMerge', 'Library', 'ApkBase', 'LibraryFile', 'PatchVersion'
      @task.update(is_read: true) if @task.present? && !@task.is_read
    end

    @total_count = User.current.notices[:total_count]
    respond_to do |format|
      format.js
    end
  end

  def library_task
    rows = Task.libraries

    render :json => rows.to_json
  rescue => e
    render :json => []
  end

  def library_task_edit
    @task = Task.find(params[:id])
    @records = @task.alter_records
  end

  def library_task_update
    @task = Task.find(params[:id])
    
    if params[:change_assigned_to].present? 
      if params[:result][:assigned_to_id].present? && @task.assigned_to_id != params[:result][:assigned_to_id].to_i
        status, messages = @task.reassigned_to(params[:result][:assigned_to_id])
      end
    else
      status, messages = @task.update_library_task(library_params)
    end

    respond_to do |format|
      if status     
        format.api  { render :text => {:success => 1, :message => l(:option_message_suc)}.to_json }      
      else
        format.api  { render :text => {:success => 0, :message => messages}.to_json }
      end
    end
  end

  def apk_base_task
    rows = Task.apk_bases

    render :json => rows.to_json
  rescue => e
    render :json => []
  end

  def apk_base_task_edit
    @task = Task.find(params[:id])
    @apk = @task.container
    @description = JSON.parse(@task.description)
    @apk_base_info = @task.build_apk_base_info
  end

  def apk_base_task_update
    @task = Task.find(params[:id])
    
    status, messages = @task.update_apk_base_task(library_params)

    respond_to do |format|
      if status     
        format.api  { render :text => {:success => 1, :message => l(:option_message_suc)}.to_json }      
      else
        format.api  { render :text => {:success => 0, :message => messages}.to_json }
      end
    end
  end

  def patch_version_task
    rows = Task.patch_versions

    render :json => rows.to_json
  rescue => e
    render :json => []
  end

  def patch_version_task_edit
    @task = Task.find(params[:id])
    @version = @task.container
    @records = @task.alter_records
  end

  def patch_version_task_update
    @task = Task.find(params[:id])
    status, messages = @task.update_patch_version_task(params[:patch_version], library_params)
    respond_to do |format|
      if status     
        format.api  { render :text => {:success => 1, :message => l(:option_message_suc)}.to_json }      
      else
        format.api  { render :text => {:success => 0, :message => messages}.to_json }
      end
    end
  end

  def library_update_task
    library_files = Task.library_files
    libraries = Task.update_libraries
    rows = libraries.concat(library_files)
    
    render :json => rows.sort{ |x,y| y <=> x }.to_json
  rescue => e
    render :json => []
  end

  def library_update_task_edit
    @task = Task.find(params[:id])
    if @task.container_type == "LibraryFile"
      @file = @task.container
      @library = @file.library
      @patch = @library.container
    elsif @task.container_type == "Library"
      @library = @task.container
      @patch = @library.container
    end
    @records = @task.alter_records
  end

  def library_update_task_update
    @task = Task.find(params[:id])
    container_params = params[:container] || nil
    status, messages = @task.update_library_update_task(container_params, library_params)
    respond_to do |format|
      if status     
        format.api  { render :text => {:success => 1, :message => l(:option_message_suc)}.to_json }      
      else
        format.api  { render :text => {:success => 0, :message => messages}.to_json }
      end
    end
  end

  def library_merge_task
    rows = Task.merge_libraries

    render :json => rows.to_json
  rescue => e
    render :json => []
  end

  def library_merge_task_edit
    @task = Task.find(params[:id])
    @library = @task.container
    @patch = @library.container
    @records = @task.alter_records
  end

  def library_merge_task_update
    @task = Task.find(params[:id])
    status, messages = @task.update_library_merge_task(library_params)
    respond_to do |format|
      if status     
        format.api  { render :text => {:success => 1, :message => l(:option_message_suc)}.to_json }      
      else
        format.api  { render :text => {:success => 0, :message => messages}.to_json }
      end
    end
  end

  private

  def task_params
    params.require(:tasks).permit(:issue_id, :issue_type, :commit_id, :branche_ids, :related_issue_ids, :related_apks, :tester_advice, :dept_result, :project_result, :master_version_id, :branch_version_ids, :reason, :requirement, :created_at)
  end

  def special_test_task_params
    params.require(:task).permit(:status)  
  end

  def result_params
    params.require(:result).permit(:steps, :start_date, :due_date, :sample_num, :catch_log_way, :result, :notes)  
  end

  def personal_task_params
    params.require(:task).permit(:name, :description, :notes, :assigned_to_id, :start_date, :due_date, :status)
  end

  def library_params
    params.require(:task).permit(:status, :notes, :assigned_to_id)
  end

  def transition_task_by_role(task)
    tras_res = {}
    plan = Plan.find(task.container_id)
    status = params[:status].to_i
    if plan.assigned_to_id == User.current.id # task assigned_to
      raise "无法操作该状态!" unless task.may_flow_to_assigned_to?
      if status == 2 || status == 3
        task.do_open!

        tras_res = {:type => 1, :message => "任务操作成功！"}
      else
        raise "无确认人，无法确认!" if plan.check_user_id.nil?
        task.do_finish! if status == 4
        task.do_refuse! if status == 7
        task.assigned_to_id = plan.check_user_id

        tras_res = {:type => 1, :message => "任务操作成功，请耐心等待确认！"}
      end
      plan.assigned_to_note = params[:note]
    end

    if plan.check_user_id == User.current.id # task check_user
      raise "无法操作该状态!" unless task.may_flow_to_check_user?
      task.do_confirm! if status == 5
      task.assigned_to_id = plan.author_id
      plan.checker_note = params[:note]

      tras_res = {:type => 1, :message => "任务已经确认，请等待SPM确认！"}
    end

    if plan.author_id == User.current.id # spm close the task
      raise "无法操作该状态!" unless task.may_flow_to_spm?
      if status == 6
        task.do_close!

        tras_res = {:type => 1, :message => "任务完成！"}
      end
      if status == 3
        task.do_reopen!

        tras_res = {:type => 1, :message => "任务已经重打开，并已经分配给了责任人！"}
      end
      task.assigned_to_id = plan.assigned_to_id
      plan.author_note = params[:note]
    end

    plan.save if task.save
    tras_res
  end

  def approve_task
    @task.status = @task_status
    @issue.update(task_params) if @task.save
  end

  def merge_task
    @task.status = @task_status
    if @task_status == 4 # developer commit to dept leader
      # handle the issue when approval
      @task.assigned_to_id = Approval.find_by_type_and_user_id("IssueToMerge", @issue.issue.assigned_to.id) || @issue.issue.assigned_to.dept_leader.id
    elsif @task_status == 6 # dept leader commit to tester
      tester = Role.find_by_name("测试负责人")
      @task.assigned_to_id = @issue.issue.project.users_of_role(tester.id).first.id
    end
    @issue.update(task_params) if @task.save
  end
end
