class Notification < ActiveRecord::Base

  STATUS_ACCEPT = 1
  STATUS_REFUSE = 2
  STATUS_IGNORE = 3
  STATUS_INVALID = 4

  belongs_to :sender, :class_name => 'User', :foreign_key => "from_user_id"
  belongs_to :receiver, :class_name => 'User', :foreign_key => "to_user_id"

  validates :category, :from_user_id, :to_user_id, presence: true

  default_scope { order(id: :desc) }
  # scope :conditions, -> {where :category => "condition"}
  scope :cate, -> (c) { where(:category => c) }

  scope :mine, -> { where :to_user_id => User.current }
  scope :unread, -> { where :is_read => false }

  def self.share_condition(cate, condition, user_ids, dept_ids)
    dept_ids.to_a.each do |dept|
      user_ids.to_a << Dept.find_by(:id => dept).all_users.visible.pluck(:id)
    end
    user_ids = user_ids.uniq.reject { |id| id == User.current.id || id == "me" }
    user_ids.each do |id|
      Notification.create(:category => cate,
                          :from_user_id => User.current.id,
                          :based_id => condition.id,
                          :to_user_id => id,
                          :subject => (cate.to_s == "report" ? condition.name.gsub('/', '') : condition.name)
      )
    end
  end

  def self.resigned_notification(recipients, options={})
    resigner = options[:resigner]
    bugs = options[:bugs]
    subject = "#{resigner} 离职通知"
    content = "您的同事 #{resigner.name} 已经离职，但其仍有未处理完的BUG，请尽快安排其他同事跟进处理[这些BUG](/issues?search=issues.id+in+(#{bugs}))。"
    admin_id = User.find_by(login: 'admin').id
    recipients.each do |recipient|
      Notification.create(:category => "system",
                          :from_user_id => admin_id,
                          :to_user_id => recipient.id,
                          :subject => subject,
                          :content => content
      )
    end
  end

  def self.undisposed_bugs_notification(recipient, options={})
    days = options[:days]
    data = options[:data]
    subject = l(:mail_subject_undisposed_bugs_notification)

    unless options[:type].in? ['manager', 'majordomo']
      chaoShiWeiJie  = data['chaoShiWeiJie']
      caiJueShenQing = data['caiJueShenQing']
      jieJueLv       = data['jieJueLv']
    end

    link_to_issue = -> (issues) {
      if issues.present?
        "[#{issues.split(',').size}](/issues?search=issues.id+in+(#{issues}))"
      else
        '0'
      end
    }
    chaoShiWeiJieTableHead = -> (name, shenqingcaijue = false) {
      "| 序号 | #{name} " + days.map do |d|
        "| " + (days[days.index(d) + 1].present?? "#{d}-#{days[days.index(d) + 1] - 1}天 " : "#{d}天及以上 ")
      end.join + ("| 裁决申请 " if shenqingcaijue).to_s + "|\n"
    }
    chaoShiWeiJieTableHeadLine = -> (n) {"| :---: | --- " + "| :---: "*(n-2) + "|\n"}


    priorityAndprob = {
      's1bx' => "S1必现解决率", 's1sj' => "S1随机解决率", 's2bx' => "S2必现解决率",
      's2sj' => "S2随机解决率", 's3bx' => "S3必现解决率", 's3sj' => "S3随机解决率",
    }
    jieJueLvTableHead = -> { "| 序号 | 项目 " + priorityAndprob.values.map{ |value| "| #{value} "}.join + "|\n"}

    case options[:type]
    when 'tester'
      return false if chaoShiWeiJie.blank?

      content = "截至#{format_date(Time.now)}，您尚有以下BUG未处理。\n\n"
      content << chaoShiWeiJieTableHead.call('项目')
      content << chaoShiWeiJieTableHeadLine.call(5)
      chaoShiWeiJie.keys.each_with_index do |project_name, index|
        value = chaoShiWeiJie[project_name]
        content << "| #{index + 1} | #{project_name} "
        days.each_with_index do |i|
          real_issue = value[i]
          if real_issue.present?
            content << "| #{link_to_issue.call real_issue} "
          else
            content << "| - "
          end
        end
        content << "|\n"
      end
    when 'developer'
      if chaoShiWeiJie.present? || caiJueShenQing.present?
        content = "截至#{format_date(Time.now)}，您尚有以下BUG未处理：\n\n"
        content << chaoShiWeiJieTableHead.call('项目', true)
        content << chaoShiWeiJieTableHeadLine.call(6)
        keys = chaoShiWeiJie.keys | caiJueShenQing.keys
        keys.each_with_index do |project_name, index|
          content << "| #{index + 1} | #{project_name} "
          # chaoShiWeiJie
          value = chaoShiWeiJie[project_name]
          days.each_with_index do |d, i|
            real_issue = value[i] rescue nil
            if real_issue.present?
              content << "| #{link_to_issue.call real_issue} "
            else
              content << "| - "
            end
          end
          # caiJueShenQing
          value = caiJueShenQing[project_name]
          content << (value.present?? "| #{link_to_issue.call value} " : "| - ")
          content << "|\n"
        end
        content << "&nbsp;\n"
      end

      if jieJueLv.present?
        content ||= ''
        content << "截至#{format_date(Time.now)}，您的BUG解决率如下：\n\n"
        content << jieJueLvTableHead.call
        content << chaoShiWeiJieTableHeadLine.call(8)
        jieJueLv.keys.each_with_index do |project_name, index|
          value = jieJueLv[project_name]
          content << "| #{index + 1} | #{project_name} "
          # jieJueLv
          priorityAndprob.keys.each do |pap|
            persent = value[pap]
            if persent.present?
              content << "| #{persent[0]} (#{link_to_issue.call persent[1]}/#{link_to_issue.call persent[2]})"
            else
              content << "| - "
            end
          end
          content << "|\n"
        end
      end
    when 'manager'
      datas = data.values

      if datas.any?{|dat| dat["chaoShiWeiJie"].present? || dat["caiJueShenQing"].present?}
        content = "截至#{format_date(Time.now)}，#{recipient.dept.orgNm} 尚有以下BUG未处理：\n\n"
        content << chaoShiWeiJieTableHead.call('姓名', true)
        content << chaoShiWeiJieTableHeadLine.call(6)
        datas.each_with_index do |dat, index|
          next if dat["chaoShiWeiJie"].blank? && dat["caiJueShenQing"].blank?
          content << "| #{index + 1} | #{dat['name']} "
          days.each_with_index do |d, i|
            real_issue = dat['chaoShiWeiJie'].map{|key, val| val[i]}.reject(&:blank?).join(",")
            if real_issue.present?
              content << "| #{link_to_issue.call real_issue} "
            else
              content << "| - "
            end
          end
          value = dat['caiJueShenQing'].values.reject(&:blank?).join(",")
          content << (value.present?? "| #{link_to_issue.call value} " : "| - ")
          content << "|\n"
        end
        content << "&nbsp;\n"
      end

      if datas.any?{|dat| dat['jieJueLv'].present?}
        content ||= ''
        content << "截至#{format_date(Time.now)}，#{recipient.dept.orgNm} BUG解决率如下：\n\n"
        content << jieJueLvTableHead.call
        content << chaoShiWeiJieTableHeadLine.call(8)
        project_names = datas.map{|dat| dat['jieJueLv'].keys}.flatten.uniq
        project_names.each_with_index do |project_name, index|
          content << "| #{index + 1} | #{project_name} "
          # jieJueLv
          priorityAndprob.keys.each do |pap|
            p1 = []
            p2 = []
            datas.each do |dat|
              values = dat['jieJueLv'].fetch(project_name){{}}[pap] || []
              next if values.blank?
              p1 << values[1]
              p2 << values[2]
            end
            p1 = p1.reject(&:blank?).join(",").split(",")
            p2 = p2.reject(&:blank?).join(",").split(",")
            p0 = p2.present?? '%.1f%' % (p1.size/p2.size.to_f*100) : ''
            # content << (p0.present?? "| #{p0} (#{link_to_issue.call p1}/#{link_to_issue.call p2})" : "| - ")
            content << (p0.present?? "| #{p0} (#{p1.present?? p1.size : 0}/#{p2.size})" : "| - ")
          end
          content << "|\n"
        end
      end
    when 'majordomo'
      if data.values.map(&:values).flatten.any?{|dat| dat["chaoShiWeiJie"].present? || dat["caiJueShenQing"].present?}
        content = "截至#{format_date(Time.now)}，#{recipient.dept.orgNm} 尚有以下BUG未处理：\n\n"
        content << chaoShiWeiJieTableHead.call('部门', true)
        content << chaoShiWeiJieTableHeadLine.call(6)
        data.keys.each_with_index do |dept, index|
          content << "| #{index + 1} | #{dept.orgNm} "
          datas = data[dept].values
          days.each_with_index do |d, i|
            real_issue = datas.map{|dat| dat["chaoShiWeiJie"]}.map{|m| m.values.map{|mm| mm[i]}}.flatten.reject(&:blank?).join(",").split(",")
            if real_issue.present?
              content << "| #{real_issue.size} "
            else
              content << "| - "
            end
          end
          value = datas.map{|dat| dat["caiJueShenQing"].values}.flatten.reject(&:blank?).join(",").split(",")
          content << (value.present?? "| #{value.size} " : "| - ")
          content << "|\n"
        end
        content << "&nbsp;\n"
      end

      if data.values.map(&:values).flatten.any?{|dat| dat["jieJueLv"].present?}
        content ||= ''
        content << "截至#{format_date(Time.now)}，#{recipient.dept.orgNm} BUG解决率如下：\n\n"
        content << jieJueLvTableHead.call
        content << chaoShiWeiJieTableHeadLine.call(8)
        project_names = data.values.map(&:values).flatten.map{|dat| dat['jieJueLv'].keys}.flatten.uniq
        project_names.each_with_index do |project_name, index|
          content << "| #{index + 1} | #{project_name} "
          # jieJueLv
          priorityAndprob.keys.each do |pap|
            p1 = []
            p2 = []
            data.values.map(&:values).flatten.each do |dat|
              values = dat['jieJueLv'].fetch(project_name){{}}[pap] || []
              next if values.blank?
              p1 << values[1]
              p2 << values[2]
            end
            p1 = p1.reject(&:blank?).join(",").split(",")
            p2 = p2.reject(&:blank?).join(",").split(",")
            p0 = p2.present?? '%.1f%' % (p1.size/p2.size.to_f*100) : ''
            # content << (p0.present?? "| #{p0} (#{link_to_issue.call p1}/#{link_to_issue.call p2})" : "| - ")
            content << (p0.present?? "| #{p0} (#{p1.present?? p1.size : 0}/#{p2.size})" : "| - ")
          end
          content << "|\n"
        end
      end
    end

    admin_id = User.find_by(login: 'admin').id
    Notification.create(:category => "system",
                        :from_user_id => admin_id,
                        :to_user_id => recipient.id,
                        :subject => subject,
                        :content => content
    )
  end

  def self.apply_umpirage_notification(recipient, options={})
    user = options[:user]
    issue = options[:issue]
    subject = l(:mail_subject_apply_umpirage_notification)
    content = "#{user.dept.try(:orgNm)} #{user.name} 申请对 BUG##{issue.id} 进行裁决，请及时处理！\n"
    content << "[立即处理](/issues/#{issue.id}) | "
    content << "[查看所有未处理的申请](/issues?search=%28#{CGI::escape recipient.condition_of_all_umpirage_apply}%29+and+issues.status_id=#{IssueStatus::APPY_UMPIRAGE_STATUS})"
    admin_id = User.find_by(login: 'admin').id

    Notification.create(:category => "system",
                        :from_user_id => admin_id,
                        :to_user_id => recipient.id,
                        :subject => subject,
                        :content => content)
  end

  def self.send_mission_to_app_spm_of_project(spec_id, project)
    # Send Notification To All APP-SPM
    sql = "roles.name = 'APP-SPM' and users.id <> #{User.current.id} and projects.production_type in (#{Project::PROJECT_PRODUCTION_TYPE[:app]},#{Project::PROJECT_PRODUCTION_TYPE[:framework]},#{Project::PROJECT_PRODUCTION_TYPE[:preload]})"
    Role.spm_users(sql).each do |user|
      Notification.create(:category => 'mission',
                          :status => 4,
                          :from_user_id => User.current.id,
                          :based_id => project.id,
                          :to_user_id => user.id,
                          :subject => "收到了来自#{project.name}项目的收集应用的通知",
                          :content => "/projects/#{project.identifier}/specs?id=#{spec_id}")
    end
  end

  def self.version_release_flow_notification(recipients, options={})
    release = options[:release]
    subject = l(:mail_subject_version_release_flow_notification)
    content = "版本 #{release.version.fullname} 正计划发布，需要您进行审核，请及时处理！ [立即处理](/version_releases/#{release.id})"
    admin_id = User.find_by(login: 'admin').id

    Array(recipients).each do |recipient|
      Notification.create(:category => "system",
                          :from_user_id => admin_id,
                          :to_user_id => recipient.id,
                          :subject => subject,
                          :content => content )
    end
  end

  def self.repo_request_notification(recipient, options={})
    key = RepoRequest::REPO_REQUEST_CATEGORY.key(recipient.category).to_s
    use = RepoRequest::REPO_REQUEST_USE.key(recipient.use).to_s if recipient.category == 1
    category = l("label_repo_request_#{key}".to_sym)
    status = l("repo_request_status_#{recipient.status}".to_sym)
    l_use = l("repo_request_use_#{use}".to_sym) if use.present?

    subject = "#{category}#{status}通知"
    if recipient.category == 3
      if recipient.production_type != 'other'
        content = "产品：#{recipient.project.name}\n"
      else
        content = "分支名：#{recipient.repo_name}\n"
      end
      text = recipient.status == "submitted" ? "需要评审" : "查看信息"
    else
      if recipient.status == "agreed"
        content = "#{recipient.project.name}项目需要填写分支信息\n"
        text = "需要处理" 
      elsif recipient.status == "submitted"
        content = "#{recipient.project.name} #{l_use}分支需要审核\n"
        text = "需要评审" 
      else
        content = "#{recipient.project.name} #{l_use}分支已#{status}\n"
        content += "分支名：#{recipient.branch}\n" if recipient.branch.present?
        text = "查看信息"
      end
    end

    content << "[#{text}](/repo_requests/#{recipient.id})"

    admin_id = User.find_by(login: 'admin').id

    case recipient.status
    when "submitted"
      case recipient.category.to_i
      when 1, 3
        to_user_ids = CustomPermission.where(permission_type: key+"_judge", locked: false).map(&:user_id)
      else
        to_user_ids = []
      end  
    when "agreed"
      to_user_ids = recipient.project.users_of_role(11).map(&:id)
    when "refused"
      to_user_ids = [recipient.author_id]
    when "successful", "failed"
      to_user_ids = [recipient.author_id]
      case recipient.category.to_i
      when 1
        to_user_ids += recipient.project.users_of_role(11).map(&:id)
      when 3
        to_user_ids += CustomPermission.where(permission_type: key+"_judge", locked: false).map(&:user_id)
      end
    when "abandoned"
      to_user_ids = recipient.project.users_of_role(11).map(&:id)
    end

    if to_user_ids.present?
      to_user_ids.uniq.each do |user_id|
        Notification.create(:category => "system",
                            :from_user_id => admin_id,
                            :to_user_id => user_id,
                            :subject => subject,
                            :content => content)
      end
    end
  end

  def self.send_okr_record_approve_notification(okr)
    subject = "OKR审批通知 \n"
    content = "[立即查看](/my/okrs/#{okr.id}/edit)"

    admin_id = User.find_by(login: 'admin').id
    Notification.create(:category => "system",
                    :from_user_id => admin_id,
                    :to_user_id => okr.approver_id,
                    :subject => subject,
                    :content => content)
  end

  def self.send_okr_record_supported_notification(recipients, options={})
    subject = "OKR需要您的支持通知"
    content = "[立即查看](/index/okrs/#{options[:okr].id}/edit)"

    admin_id = User.find_by(login: 'admin').id
    recipients.each do |recipient|
      Notification.create(:category => "system",
                      :from_user_id => admin_id,
                      :to_user_id => recipient,
                      :subject => subject,
                      :content => content)     
    end
  end

  def self.send_user_submit_okrs_record(recipients, options={})
    subject = "OKR填写通知"

    admin_id = options[:admin_id]
    recipients.each do |recipient|
      puts "---------------send notice to user id: #{recipient}-------------------"
      Notification.create(:category => "system",
                      :from_user_id => admin_id,
                      :to_user_id => recipient,
                      :subject => subject)     
    end
  end

  def self.send_okr_record_recall_notification(okr)
    subject = "OKR审批撤回通知 \n"
    content = "[立即查看](/my/okrs/#{okr.id}/edit)"

    admin_id = User.find_by(login: 'admin').id
    Notification.create(:category => "system",
                    :from_user_id => admin_id,
                    :to_user_id => okr.approver_id,
                    :subject => subject,
                    :content => content)    
  end

  def update_depend_on(key, category = 1)
    case key
      when 'accept'
        self.accept!
        unless category == 4
          condition = $db.slave { Condition.find_by(:id => self.based_id) }
          if condition.blank?
            self.void!
          else
            # condition_folder = User.current.conditions.find_by(:name => "我收到的查询条件")
            condition_folder = $db.slave { User.current.conditions.find_by_name_and_category("我收到的查询条件", category) }
            condition_folder = $db.slave { User.current.conditions.create(:name => "我收到的查询条件", :is_folder => true, :category => category) } if (condition_folder.blank? || !condition_folder.is_folder)
            condition.dup.update_attributes(:user_id => User.current.id, :folder_id => condition_folder.id)
          end
        end
      when 'refuse'
        self.refuse!
      when 'ignore'
        self.ignore!
      when 'read'
        self.read!
    end
  end


  def accepted?
    self.status == STATUS_ACCEPT
  end

  def refused?
    self.status == STATUS_REFUSE
  end

  def ignored?
    self.status == STATUS_IGNORE
  end

  def invalid?
    self.status == STATUS_INVALID
  end

  def accept!
    update_attributes(:is_read => true, :status => STATUS_ACCEPT)
  end

  def refuse!
    update_attributes(:is_read => true, :status => STATUS_REFUSE)
  end

  def ignore!
    update_attributes(:is_read => true, :status => STATUS_IGNORE)
  end

  def void!
    update_attributes(:is_read => true, :status => STATUS_INVALID)
  end

  def read!
    update_attribute(:is_read, true)
  end

end


