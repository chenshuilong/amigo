namespace :amigo do
  desc 'To Sync Dept Information'
  task :dept_sync => :environment do
    # response = HTTParty.get "http://16.6.10.18:8088/Usr!org4DeptTreeAll.shtml" # 部门架构
    # response = HTTParty.get "http://16.6.10.18:8088/Usr!org4DeptTree4OS.dtml"
    active_dept_ids = []
    response = HTTParty.get "http://16.6.10.18:8088/Usr!organDeptOs.shtml"
    JSON.parse(response.body).each do |dept|
      dept_columns = {
          :orgNo => dept["deptNo"],
          :orgNm => dept["deptNm"],
          :parentNo => dept["parentDeptNo"],
          :status => dept["status"],
          :manager_id => dept["jingLi1ID"],
          :comNm => dept["comNm"],
          :parentNm => dept["parentDeptNm"],
          :manager_number => dept["jingLi1No"],
          :manager_name => dept["jingLi1Nm"],
          :manager2_number => dept["jingLi2No"],
          :manager2_name => dept["jingLi2Nm"],
          :sub_manager_number => dept["fuJingLi1No"],
          :sub_manager_name => dept["fuJingLi1Nm"],
          :sub_manager2_number => dept["fuJingLi2No"],
          :sub_manager2_name => dept["fuJingLi2Nm"],
          :supervisor_number => dept["zhuGuan1No"],
          :supervisor_name => dept["zhuGuan1Nm"],
          :supervisor2_number => dept["zhuGuan2No"],
          :supervisor2_name => dept["zhuGuan2Nm"],
          :majordomo_number => dept["zongJianNo"],
          :majordomo_name => dept["zongJianNm"],
          :sub_majordomo_number => dept["fuZongJianNo"],
          :sub_majordomo_name => dept["fuZongJianNm"],
          :vice_president_number => dept["zhuGuanFuZongNo"],
          :vice_president_name => dept["zhuGuanFuZongNm"],
          :vice_president2_number => dept["zhuGuanFuZong2No"],
          :vice_president2_name => dept["zhuGuanFuZong2Nm"]
      }
      d = Dept.find_by(orgNo: dept['deptNo'])
      unless d
        dt = Dept.create(dept_columns)

        if dt
          puts "Add: #{dept['deptNm']}"
        else
          puts "Add error: #{dept['deptNm']}"
        end
      else
        active_dept_ids << d.id
        if d.update_attributes(dept_columns)
          puts "Updated: #{dept['deptNm']}"
        else
          puts "Update error #{dept['deptNm']}"
        end
      end
    end

    # Locked dept when hr close the dept
    Dept.where("id not in (#{active_dept_ids.join(',')}) and orgNo not in ('10100000','10100001','20100000','20100111','30100000','88100000')").update_all({:status => Dept::STATUS_LOCKED}) unless active_dept_ids.blank?

    Dept.build_dept_tree # Refresh depts tree in Redis
  end

  desc 'To Sync User Information'
  task :user_sync => :environment do
    puts "---------------- User Sync Job Starts at #{Time.now.to_s(:db)} ----------------"
    page_size = 500
    (1..200).each do |page_index|
      begin
        deps = Dept::USER_SYNC_DEPT
        rows = Api::User.where(:page => page_index, :per_page => page_size)
        if !rows.blank?
          rows.each do |u|
            user = User.find_by_login(u['id'])
            if user.present? || (deps & Dept.find_by(:orgNo => u["orgNo"]).try(:all_up_levels).to_a).present?
              if !user # New user
                if u["status"].to_i != 0
                  puts "Add: #{u["usrName"]}"
                  nuser = User.new
                  nuser.attributes = (nuser.attributes.keys & u.keys).reject { |r| %w(id status gender).include?(r) }.inject({}) { |r, e| r[e] = u[e]; r }
                  nuser.safe_attributes = nuser.login
                  nuser.login = u["id"]
                  nuser.mail = u["mailAddr"]
                  nuser.firstname = u["usrName"]
                  nuser.gender = u["gender"] == "1"
                  nuser.native_place = u["brithAdd"]
                  nuser.married = u["maritalNm"]
                  nuser.entry_date = u["inDate"]
                  if nuser.save
                    nuser.cas_active
                  else
                    puts "Add error, empId is #{u["id"]}"
                  end
                end
              elsif user.status != 3 # Modify User
                # puts "Modify: #{user.firstname}"
                if u["status"].to_i == 0 # leave status
                  user.firstname = "#{user.firstname}(离职)"
                  user.status = 3
                  user.mail = ""
                else
                  user.mail = u["mailAddr"] # if user.mails.reject(&:blank?).blank?
                  user.attributes = (user.attributes.keys & u.keys).reject { |r| %w(id status gender mobile phone).include?(r) }.inject({}) { |r, e| r[e] = u[e]; r }
                  user.mobile = u["mobile"] if user.mobile.blank?
                  user.phone = u["phone"] if user.phone.blank?
                  user.gender = u["gender"] == "1"
                  user.native_place = u["brithAdd"]
                  user.married = u["maritalNm"]
                  user.entry_date = u["inDate"]
                end
                puts "Update error, Login is #{u["id"]}" unless user.save
              end
            end
          end
        end
      rescue => e
        puts e.to_s
      end
    end

    # Add user's dept name when have orgNo
    User.where("orgNo is not null and orgNm is null").each do |user|
      dept = Dept.find_by_orgNo(user.orgNo)
      if dept.present?
        user.orgNm = dept.orgNm
        user.save
      end
    end
  end

  desc 'To Sync Group Information'
  task :group_sync => :environment do
    puts "---------------- Group Sync Job Starts at #{Time.now.to_s(:db)} ----------------"
    groups = Dept::USER_GROUP_DEPT
    groups.each do |g|
      @group = Group.find_by(:lastname => g[:to_group_name])
      if @group.present?
        begin
          @group.users.select { |user| user.locked? }.each { |u| @group.users.delete u } # Remove if user status is locked
          g[:from_dept_no].each do |d|
            users = Dept.find_by(:orgNo => d).all_users
            add_users = users.not_in_group(@group).status(1).to_a.reject { |user| user.jobNm == "集团副总裁" } # Add new user to group
            @group.users << add_users
            puts "[#{Time.now.to_s(:db)}] Add to group #{g[:to_group_name]}: #{add_users*','}" if add_users.count > 0
          end
        rescue => e
          puts "[#{Time.now.to_s(:db)}] An error occured: #{e.to_s}"
        end
      else
        puts "[#{Time.now.to_s(:db)}] There is no Group: #{g[:to_group_name]}"
      end
    end
  end

  desc 'Resigned Staff Who Has Project Bugs Notification'
  task :resigned_notice => :environment do
    puts "---------------- Resigned Staff Notice Job Starts at #{Time.now.to_s(:db)} ----------------"
    users = User.status(3).where(:updated_on => Time.now.midnight...Time.now)
    users.each do |user|
      bugs = Issue.on_active_project.open.where("assigned_to_id = #{user.id} OR author_id =#{user.id}").uniq
      if bugs.present?
        begin
          superior = [user.superior]
          spms = bugs.map(&:project).uniq.map { |p| p.members.includes(:roles).where(:roles => {:name => "SPM"}).map(&:user) }.flatten.uniq
          all_receiver = superior | spms
          bugs = bugs.map(&:id).join(",")
          ActionMailer::Base.raise_delivery_errors = true
          begin
            Mailer.with_synched_deliveries do
              Mailer.resigned_notification(all_receiver, :resigner => user, :bugs => bugs).deliver # Send email
            end
          rescue => e
            puts "[#{Time.now.to_s(:db)}] #{e.message}"
          end
          Notification.resigned_notification(all_receiver, :resigner => user, :bugs => bugs) # Push notification
          puts "[#{Time.now.to_s(:db)}] Mail about resignation of #{user.name} has been sent."
        rescue => e
          puts "[#{Time.now.to_s(:db)}] An error occured: #{e.to_s}"
        end
      end
    end
  end

  desc 'Staff Everyday Issue Analyzing Notification'
  task :undisposed_notice => :environment do
    puts "---------------- Everyday Issue Analyzing Notice Job Starts at #{Time.now.to_s(:db)} ----------------"
    unless Api::WorkDay.day(Date.today) # Return if weekend
      puts "[#{Time.now.to_s(:db)}] END, today is off."
    else
      days = [3, 7, 10]
      # projects = Project.where(:id => 190)
      projects = Project.ongoing
      if projects.blank?
        puts 'No any projects'
        return true
      end

      users = User.active
                  .joins("inner join issues on issues.assigned_to_id = users.id")
                  .where(:issues => {:project_id => projects.pluck(:id), :by_tester => true})
                  .uniq
      # result = YAML.load_file '/data/issue_analyzing/2017/2017-07-12.yml'
      result = Report.issue_analyzing(projects, users, days)

      # Write to result to /data/issue_analyzing/:year/:date.yml
      save_dir = "/data/issue_analyzing/#{Date.current.year}"

      FileUtils.mkdir_p save_dir unless Dir.exist?(save_dir)
      File.write("#{save_dir}/#{Date.current.to_s}.yml", result.to_yaml)


      # handle users
      manager_scope = [:manager_number, :manager2_number, :sub_manager_number, :sub_manager2_number]
      majordomo_scope = [:majordomo_number, :sub_majordomo_number]
      all_users = User.where(:id => result.keys)
      tester_users = all_users.select(&:is_tester?)
      developer_users = all_users.where.not(:id => tester_users)
      manager_ids = developer_users.joins(:dept).pluck(*manager_scope).map { |m| m.detect { |mm| mm.to_i > 0 } }.compact
      majordomo_ids = developer_users.joins(:dept).pluck(*majordomo_scope).map { |m| m.detect { |mm| mm.to_i > 0 } }.compact

      need_send_tester = tester_users
      need_send_manager = User.where(:empId => manager_ids)
      need_send_developer = developer_users
      need_send_majordomo = User.where(:empId => majordomo_ids)

      # send to tester, just send chaoShiWeiJie
      ActionMailer::Base.raise_delivery_errors = true

      [need_send_tester, need_send_developer, need_send_manager, need_send_majordomo].each_with_index do |users, index|
        type = %w(tester developer manager majordomo)[index]
        users.each do |user|
          case index
            when 0
              data = result[user.id]
              next if data["chaoShiWeiJie"].blank?
            when 1
              data = result[user.id]
            when 2
              stuff = need_send_developer.joins(:dept).where(manager_scope.map { |m| "#{m.to_s} = ?" }.join(" OR "), *Array.new(4, user.empId))
              data = result.slice(*stuff.pluck(:id))
            when 3
              dept_children = user.dept.children
              data = {}
              dept_children.each do |dept|
                all_down_depts_of_current_dept = dept.all_down_depts
                stuff = need_send_developer.where(:orgNo => all_down_depts_of_current_dept)
                data[dept] = result.slice(*stuff.pluck(:id)) if stuff.present?
              end
              next unless data.present?
          end

          Notification.undisposed_bugs_notification(user, :type => type, :days => days, :data => data)
          begin
            Mailer.with_synched_deliveries do
              Mailer.undisposed_bugs_notification(user, :type => type, :days => days, :data => data).deliver
            end
          rescue => e
            puts "=> [#{Time.now.to_s(:db)}] #{e.message}"
          end

          puts "[#{Time.now.to_s(:db)}] Mail about issues analyzing for #{type}: #{user.firstname} has been sent."
        end
      end

      # depts = Dept::NOTICE_UNDISPOSED_BUGS_DEPT # OS
      # days = [3, 7, 10]
      # depts.each do |dept|
      #   d = Dept.find_by(:orgNo => dept)
      #   d.nil? ? next : small_depts = d.all_smallest_depts.reject { |r| r.orgNo == Dept::SQA_DEPT }
      #   small_depts.each do |sd|
      #     users = sd.all_users.status(1)
      #     data = users.map { |u| [u, u.undisposed_over(days)] }.select { |r| r.last.flatten.compact.present? }
      #     next if users.blank? || data.blank?
      #     all_receiver = users.to_a
      #     all_receiver << User.find_by(:login => users.first.group_bmjl_id) if users.first.group_bmjl_id.present?
      #     all_receiver << User.find_by(:login => users.first.group_zhuguan_id) if users.first.group_zhuguan_id.present?
      #     all_receiver.compact!
      #     # all_receiver = [User.find(1125)] # For Test
      #     ActionMailer::Base.raise_delivery_errors = true
      #     begin
      #       Mailer.with_synched_deliveries do
      #         Mailer.undisposed_bugs_notification(all_receiver, :days => days, :data => data).deliver
      #       end
      #     rescue => e
      #       puts "[#{Time.now.to_s(:db)}] #{e.message}"
      #     end
      #     Notification.undisposed_bugs_notification(all_receiver, :days => days, :data => data) # Push notification
      #     puts "[#{Time.now.to_s(:db)}] Mail about undisposed bugs group name #{users.first.dept.orgNm} has been sent."
      #   end
      # end
    end
  end

  desc 'Check Attachment Merging'
  task :attachment_merge_check => :environment do
    puts "---------------- Check Attachment Merging at #{Time.now.to_s(:db)} ----------------"
    Attachment.unmerge.each do |atta|
      if atta.created_on < Time.now && atta.created_on > 2.days.ago
        puts "[#{Time.now.to_s(:db)}] Add Attachment: #{atta.id} to sidekiq queue."
        FileMergerJob.perform_later(atta.id)
      end
    end
  end

  desc 'Clear up files/temp/*.* Files'
  task :clear_temp_file => :environment do
    puts "---------------- Clean Temp File at #{Time.now.to_s(:db)} ----------------"
    Attachment.where(created_on: 2.days.ago..Time.now).where(container_id: nil).pluck(:uniq_key).uniq.each do |uniq_key|
      FileUtils.rm_rf(Dir.glob(File.join(Attachment::ROOT_DIR, "files/temp/#{uniq_key}.*")))
    end

    Export.undeleted.where(updated_at: 3.days.ago..Time.now).each do |export|
      FileUtils.rm_rf export.file_path if File.exist? export.file_path
      export.update_column :deleted, true
    end
    puts "[#{Time.now.to_s(:db)}] There discarded files has been removed."
  end

  desc 'Pick up the issue at timestamp once'
  task :pick_issue_status_at_timestamp_once => :environment do
    puts "---------------- Add bugs start at #{Time.now.to_s(:db)} ----------------"
    start_dt = "2016-09-01"
    end_dt = "2017-01-01"
    (Date.parse(start_dt)..Date.parse(end_dt)).each do |time|
      Issue.daily_by_test("#{time} 00:00:00").each { |issue|
        his = IssueHistory.new
        [:status_id, :assigned_to_id, :project_id, :priority_id, :probability_id, :mokuai_name].each do |prop_key|
          if prop_key.eql?(:probability_id)
            iss = issue.pick_up_by_time("cf", "2", "#{time} 00:00:00")
            if iss[:cf2]
              his.date = time
              his.issue_id = issue.id
              his[prop_key] = iss[:cf2]
              his.save
            end
          else
            iss = issue.pick_up_by_time("attr", prop_key.to_s, "#{time} 00:00:00")
            if iss[prop_key]
              his.date = time
              his.issue_id = issue.id
              his[prop_key] = iss[prop_key]
              his.save
            end
          end
        end
      }
    end
    puts "---------------- Add bugs end at #{Time.now.to_s(:db)} ----------------"
  end

  desc 'Pick up the issue at timestamp everyday'
  task :pick_issue_status_at_timestamp => :environment do
    puts "---------------- Add bugs start at #{Time.now.to_s(:db)} ----------------"
    time = Time.now.strftime("%Y-%m-%d")

    Issue.daily_by_test("#{time} 00:00:00").each { |issue|
      unless IssueHistory.find_by_issue_id_and_date(issue.id, "#{time} 00:00:00").present?
        his = IssueHistory.new
        [:status_id, :assigned_to_id, :project_id, :priority_id, :probability_id, :mokuai_name].each do |prop_key|
          if prop_key.eql?(:probability_id)
            iss = issue.pick_up_by_time("cf", "2", "#{time} 00:00:00")
            if iss[:cf2]
              his.date = time
              his.issue_id = issue.id
              his[prop_key] = iss[:cf2]
              his.save
            end
          else
            iss = issue.pick_up_by_time("attr", prop_key.to_s, "#{time} 00:00:00")
            if iss[prop_key]
              his.date = time
              his.issue_id = issue.id
              his[prop_key] = iss[prop_key]
              his.save
            end
          end
        end
      end
    }
    puts "---------------- Add bugs end at #{Time.now.to_s(:db)} ----------------"
  end

  desc 'Backup databse in production environment'
  task :db_backup => :environment do
    puts "---------------- Database backup start at #{Time.now.to_s(:db)} ----------------"

    # Clear backup > 7 days
    back_folder = Rails.root.join('..', '..', 'shared', 'db')
    files = Dir.glob(back_folder.join("*.sql")).select { |f| File.ctime(f) < 7.days.ago }
    FileUtils.rm_rf(files) if files.present?

    # Do backup database
    data = YAML.load_file Rails.root.join('config', 'database.yml')
    data = data['production']
    user, password, database, host = data['username'], data['password'], data['database'], data['host']
    filename = "amigo-db-backup-#{Date.current.to_s}.sql"
    dest = back_folder.join(filename)
    basic_config = '--port=3306 --default-character-set=utf8 --routines --no-create-info=FALSE --skip-triggers'
    `mysqldump --user=#{user} --password=#{password} #{basic_config} --host=#{host}  #{database} > #{dest}`

    puts "[#{Time.now.to_s(:db)}] Database backup task has been done."
  end

  desc 'Running periodic tasks, eg: periodic versions'
  task :periodic_task => :environment do
    # Periodic versions
    pves = $db.slave { VersionPeriodicTask.where("status = 1 AND
                                      weekday LIKE '%#{Date.current.wday}%' AND (
                                      last_running_on < '#{Date.current.midnight}' OR
                                      last_running_on IS NULL ) AND
                                      TIME(time) <= '#{Time.now.to_s(:time)}'").order(time: :asc) }
    abort if pves.blank?

    puts "---------------- Periodic version tasks start at #{Time.now.to_s(:db)} ----------------"
    pves.each do |pv|
      next if pv.created_at.today? && (Time.now - Time.parse(pv.time.to_s(:time))) > 20.minutes

      version = pv.build_version
      rule_range = version.rule.range

      if rule_range.present? && version.name > rule_range.split('-').last
        warning_message = '版本号已经超出上限'
        pv.update_columns(:status => pv.class.consts[:status][:exceptional], :warning => warning_message)
        puts "[#{Time.now.to_s(:db)}] #{warning_message}: #{pv.name}"
      else
        begin
          version.save!
          pv.update_columns(:last_running_on => Time.now, :running_count => pv.running_count.to_i + 1)
          puts "[#{Time.now.to_s(:db)}] Version created: #{pv.name}, #{version.fullname}"
        rescue => e
          puts "Error occured: #{e}"
          puts "[#{Time.now.to_s(:db)}] Version failed: #{pv.name}, #{version.errors.messages}"
        end
      end

      sleep 1.second # Sleep 1 second to avoid version name repeated
    end
  end

  desc 'Oversea project, spec, version migrate'
  task :import_oversea_versions => :environment do
    begin
      excel_file = Project.find(426).attachments.second.diskfile
      lines = Roo::Excelx.new(excel_file, packed: false, file_warning: :ignore)

      lines.each do |line|
        plat_fullname = line[0]
        version_fullname = line[1]
        fengban_date = line[2]
        desc_one = line[3]
        desc_two = line[4]
        desc_thd = line[6]

        idfer = "#{version_fullname.split('_')[0]}_#{plat_fullname.gsub('平台', '')}"
        project = Project.find_by_identifier(idfer)

        # Create project if not exist
        if project.blank?
          project_parent = Project.where("identifier = '#{idfer[0..6]}A_#{plat_fullname.gsub('平台', '')}' AND parent_id IS NULL").order('identifier').first
          project = Project.new({:name => "#{version_fullname.split('_')[0]}(#{plat_fullname.gsub('平台', '')})",
                                 :identifier => idfer,
                                 :parent_id => project_parent.blank? ? nil : project_parent.id,
                                 :category => 1, :hardware_group => '深研', :product_serie => 'M系列',
                                 :external_name => version_fullname.split('_')[0], :cta_name => version_fullname.split('_')[0],
                                 :app_version_type => "...", :ownership => 2, :mokuai_class => 1
                                })
          project.save
        end

        if project.present?
          spec_name = "_" + version_fullname.split('_')[1].to_s.strip
          if project.specs.reload.find_by_name_and_deleted(spec_name, false).blank?
            project.specs << Spec.new({:name => spec_name, :freezed => 1, :locked => 1, :for_new => 1, :deleted => 0})
          end

          spec_id = project.specs.reload.find_by_name_and_deleted(spec_name, false).id
          version_name = version_fullname.split('_').last.gsub('V', 'T').strip
          ver = project.versions.reload.find_by_name_and_spec_id(version_name, spec_id)
          if ver.blank?
            # validates :name, :status, :priority, :spec_id, :repo_one_id, presence: true
            project.versions << ::Version.new({:name => version_name, :status => 3, :compile_status => 6,
                                               :compile_type => 1, :repo_one_id => 3, :priority => 4,
                                               :spec_id => spec_id, :description => [desc_one, desc_two, desc_thd].join("\r\n")})
          else
            ver.description = [desc_one, desc_two, desc_thd].join("\r\n")
            ver.save
          end
        end
      end

    rescue => e
      puts "=======#{e.message.to_s}========"
    end
  end

  desc 'Handle project after inherited members'
  task :remove_inherited_members => :environment do
    begin

      project = Project.find(1421)
      if project.present? && project.active?
        # Remove project's inherit members
        project.inherit_members = false

        # Copy project's members by template
        CopyProjectMembersJob.perform_later(project.id, 1142) if project.save
      end

    rescue => e
      puts "=======#{e.message.to_s}========"
    end
  end

  desc 'Change log url from ftp to http'
  task :change_log_address => :environment do
    begin

      # Update all quality_log ftp url
      quality_log = "description LIKE '%ftp://jmpzbrjcs:jmpzbrjcs@19.9.0.162%'"
      ActiveRecord::Base.connection.execute("update issues set description = REPLACE(description, 'ftp://jmpzbrjcs:jmpzbrjcs@19.9.0.162', 'http://19.9.0.162/quality_log/') where #{quality_log}")

      # Update all oversea_log ftp url
      oversea_log = "description LIKE '%ftp://oversea_log:twd3_tVu@%'"
      ActiveRecord::Base.connection.execute("update issues set description = REPLACE(description, 'ftp://oversea_log:twd3_tVu@', 'http://') where #{oversea_log}")

      # Update all cq_log ftp url
      cq_log = "description LIKE '%ftp://cqlog:cqlog@%'"
      ActiveRecord::Base.connection.execute("update issues set description = REPLACE(description, 'ftp://cqlog:cqlog@', 'http://') where #{cq_log}")

      # Update all int_log ftp url
      int_log = "description LIKE '%ftp://int_log:ec6axWq@%'"
      ActiveRecord::Base.connection.execute("update issues set description = REPLACE(description, 'ftp://int_log:ec6axWq@', 'http://') where #{int_log}")

      # Update all autotest_log ftp url
      autotest_log = "description LIKE '%ftp://autotest:autotest@%'"
      ActiveRecord::Base.connection.execute("update issues set description = REPLACE(description, 'ftp://autotest:autotest@', 'http://') where #{autotest_log}")

      # Update all spec_versons when production_id is null
      SpecVersion.where(:production_id => nil).each { |sv|
        sv.production_id = Version.find(sv.version_id).project_id
        sv.save
      }

    rescue => e
      puts "=======#{e.message.to_s}========"
    end
  end

  desc 'Upload thirdparty zip files'
  task :upload_thirdparty_files => :environment do
    begin

      # Handle zip to remote server
      Thirdparty.preload_apps.where("status = 1 and length(version_ids) = 7 and release_ids is null").each { |tdp|
        tdp.extract_zip_file
        sleep(30)
        tdp.make_android_mk_to_zip
        sleep(30)
        tdp.upload_zip_to_server
      }

    rescue => e
      puts "=======#{e.message.to_s}========"
    end
  end

  desc 'Notice user submit new okr record'
  task :okrs_submit_notice => :environment do 
    begin
      @setting = OkrsSetting.last
      @setting.send_notice if @setting.present?
    rescue
      puts "=======#{e.message.to_s}========"
    end
  end

  desc 'Refresh menus for all users'
  task :refresh_user_redis => :environment do
    begin
      menus = ['amigo_main_menus', 'amigo_personal_menus', 'amigo_faster_new_menus', 'amigo_notice_menus']
      User.active.each { |user|
        menus.each { |menu|
          $redis.del("#{menu}[#{user.id}]") if $redis.smembers("#{menu}[#{user.id}]").present?
        }
      }
    rescue
      puts "=======#{e.message.to_s}========"
    end
  end
end
