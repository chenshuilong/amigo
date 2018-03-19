class PatchVersion < ActiveRecord::Base
  belongs_to :patch, foreign_key: "patch_id"
  belongs_to :test_manager, class_name: "User", foreign_key: "test_manager_id"
  belongs_to :software_manager, class_name: "User", foreign_key: "software_manager_id"
  belongs_to :user, class_name: "User", foreign_key: "user_id"

  def need_resolve?
    (result == "NG") || (status == "success" && result.blank?)
  end

  def confirm_result(result, task_id)
    version_params = {}
    case status
    when "success"
      old_result = self.result
      old_role_type = self.role_type
      old_user = self.user
      user_type = l("patch_version_role_type_#{old_role_type}")
      version_params[:result] = result[:result]
      if old_result == "NG" && result[:result] == "PASS"
        version_params[:operate_type] = category
        patch_notes  = "Patch "+ l("patch_jenkins_task#{category}") +" #{name}: #{user_type}#{old_user.firstname}确认gionee_master问题已修复, 确认结果为#{result[:result]}."
      elsif old_result.blank? && result[:result] == "PASS"
        version_params[:operate_type] = category == "precompile" ? 'task_002' : 'task_003'
        patch_notes  = "Patch "+ l("patch_jenkins_task#{category}") +" #{name}: #{user_type}#{old_user.firstname}确认结果为#{result[:result]}."
      elsif old_result.blank? && result[:result] == "NG"
        version_params[:operate_type] = nil
        version_params[:user_id] = software_manager.id
        version_params[:role_type] = "software"
        patch_notes  = "Patch "+ l("patch_jenkins_task#{category}") +" #{name}: #{user_type}#{old_user.firstname}确认结果为#{result[:result]}."
      end
      if self.update(version_params)
        patch.alter_records.create(notes: patch_notes)
        if self.result == "NG"
          @task = Task.find(task_id)
          @task.update_columns(assigned_to_id: self.user_id, is_read: false)
          unlock = category == "precompile" ? "gionee_master" : "gionee_update_master" 
          patch.do_jenkins_job("unlock", unlock: unlock)
        end
        check_to_do_jenkins_job
      end

    when "failed"
      version_params[:result] = result[:result]
      version_params[:operate_type] = category
      user_type = l("patch_version_role_type_#{self.role_type}")
      if self.update(version_params)
        patch_notes  = "Patch "+ l("patch_jenkins_task#{category}") +" #{name}: #{user_type}#{self.user.firstname}确认gionee_master问题已修复, 确认结果为#{self.result}."
        patch.alter_records.create(notes: patch_notes)
        check_to_do_jenkins_job
      end
    end
  end

  #检测是否发送jenkins请求
  #
  #
  def check_to_do_jenkins_job
    ng_count = patch.patch_versions.where(result: "NG").count
    result_nil_count = patch.patch_versions.where(result: nil).count
    operate_type_not_nil_count = patch.patch_versions.where.not(operate_type: nil).count
    operate_type_to_compile_count = patch.patch_versions.where(operate_type: ["precompile", "postcompile"]).count
    operate_type_to_task_count = patch.patch_versions.where(operate_type: ["task_002", "task_003"]).count

    status = ng_count == 0 && result_nil_count == 0 && (operate_type_not_nil_count == operate_type_to_compile_count + operate_type_to_task_count)

    if status
      if operate_type_to_compile_count > 0
        task = category
      else
        task = category == "precompile" ? "task_002" : "task_003"
      end

      PatchVersion.transaction do 
        patch.do_jenkins_job(task)
        patch.patch_versions.update_all(operate_type: nil)
      end
    end

    return true
  end
end
