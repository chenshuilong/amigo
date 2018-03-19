class Report
  # ActiveRecord::Base.establish_connection(:adapter => "mysql2",
  #                                         :encoding=>'utf8',
  #                                         :reconnect=>false,
  #                                         :pool=>20,
  #                                         :host =>'18.8.10.96',
  #                                         :database => "gnrom",
  #                                         :username=>"root",:password=>"r@@t")

  # Every day bug analyzing
  class << self

    def issue_analyzing(based_projects, based_users, days)
      # normal_assigned_last_statuses       = %(提交 分配 重分配 打开 重打开 三方分析 申请裁决)
      # normal_assigned_last_last_statuses  = %(提交 分配 重分配 打开 重打开 三方分析 申请裁决)

      # valid_assigned_last_statuses        = %(已修复)
      # valid_assigned_last_last_statuses   = %(提交 分配 重分配 打开 重打开 三方分析 申请裁决)

      # invalid_assigned_last_statuses      = %(裁决 拒绝 重复 无效 无法复现 需求 协商关闭 无法理解 挂机)
      # invalid_assigned_last_last_statuses = %(提交 分配 重分配 打开 重打开 三方分析 申请裁决)

      # normal_received_statuses            = %(提交 分配 重分配 打开 重打开 三方分析 申请裁决)
      # invalid_received_last_statuses      = %(重分配 重打开)
      # invalid_received_last_last_statuses = %(已修复 集成 关闭 裁决 拒绝 重复 无效 无法复现 需求 协商解决 无法理解 挂机)

      # Output everyones bug, and save to /data/issue_analyzing
      result = {}
      based_users.each do |user|
        # output chaoShiWeiJie
        chaoShiWeiJie = {}
        based_projects.each do |project|
          bugs = undisposed_issues(user, days, project)
          chaoShiWeiJie[project.name] = bugs.map{|bug| bug.compact.join(',')} unless bugs.flatten.all?(&:blank?)
        end

        # output CaijueShenQing
        caiJueShenQing = {}
        based_projects.each do |project|
          bugs = umpirage_issues(user, project)
          caiJueShenQing[project.name] = bugs.compact.join(',') unless bugs.flatten.all?(&:blank?)
        end

        # output jieJuelv
        jieJueLv = {}
        priority_prob = {s1bx: [4, '必现'], s1sj: [4, %w(随机 单机必现)], s2bx: [3, '必现'], s2sj: [3, %w(随机 单机必现)], s3bx: [2, '必现'], s3sj: [2, %w(随机 单机必现)]}
        based_projects.each do |project|
          priority_prob_per_project = {}
          priority_prob.map do |index, value|
            bugs = resolve_rate(user, *value, project)
            priority_prob_per_project[index.to_s] = bugs.map{|bug| bug.is_a?(Array) ? bug.join(',') : bug} unless bugs.last.blank?
          end
          jieJueLv[project.name] = priority_prob_per_project unless priority_prob_per_project.values.flatten.all?(&:blank?)
        end

        if chaoShiWeiJie.present? || caiJueShenQing.present? || jieJueLv.present?
          result[user.id] = {'name' => user.name, 'chaoShiWeiJie' => chaoShiWeiJie, 'caiJueShenQing' => caiJueShenQing, 'jieJueLv' => jieJueLv}
        end
      end

      result
    end

    # 超时未解BUG
    def undisposed_issues(user, days, project = nil)
      return [] if days.blank?
      demand_id = IssuePriority.demand.present?? IssuePriority.demand.id : 0
      issues = Issue.on_active_project.where("tracker_id = 1 AND by_tester = 1 AND priority_id <> #{demand_id} AND status_id IN (#{IssueStatus::LEAVE_STATUS}) AND assigned_to_id = #{user.id}")
      issues = issues.where(:project_id => project.id) if project.present?
      issues.map do |issue|
        details = JournalDetail.select("journal_details.*, journals.user_id, journals.created_on")
                               .joins(journal: :issue)
                               .where("issues.id = ?", issue.id)
                               .order("journals.created_on DESC")
                               .to_a
        lastest_record = details.select{ |d| d.prop_key == "assigned_to_id" }.first # Last assigned date
        lastest_record ||= details.select{ |d| d.prop_key == "status_id" }.first  # Last status change date
        if lastest_record.present?
          lastest_edit = issue.journals.where("user_id = ? AND created_on > ?", user.id, lastest_record.created_on).order(created_on: :desc).first
          since_date = (lastest_edit || lastest_record).created_on
          days.map do |day|
            undisposed_day = (Date.today - since_date.to_date).to_i
            nextday = days[days.index(day) + 1]
            if nextday.present? # Not last element
              undisposed_day >= day && undisposed_day < nextday ? issue.id : nil
            else
              undisposed_day >= day ? issue.id : nil
            end
          end
        end
      end.compact.transpose
    end

    # BUG解决率
    def resolve_rate(user, priority, prob, project = nil)
      return [] if (priority.nil? || prob.nil?)

      solved_statuses = %w(已修复 关闭)
      avaliable_statuses = %w(分配 重分配 打开 重打开 申请裁决 三方分析 已修复 关闭)

      base_issues = Issue.on_active_project.joins(:custom_values).where("assigned_to_id = ? AND priority_id = ? AND custom_field_id = 2", user.id, priority).where(:custom_values => {:value => prob})
      base_issues = base_issues.where(:project_id => project.id) if project.present?
      solved_issues = base_issues.joins(:status).where(:issue_statuses => {:name => solved_statuses}).pluck(:id)
      avaliable_issues = base_issues.joins(:status).where(:issue_statuses => {:name => avaliable_statuses}).pluck(:id)
      rate = avaliable_issues.length.zero?? '' : ('%.1f%' % (solved_issues.length/avaliable_issues.length.to_f*100))

      [rate, solved_issues, avaliable_issues]
    end

    # 申请裁决的BUG
    def umpirage_issues(user, project = nil)
      issues = Issue.on_active_project.where("assigned_to_id = ? AND status_id = ?", user.id, IssueStatus::APPY_UMPIRAGE_STATUS)
      issues = issues.where(:project_id => project.id) if project.present?
      issues.pluck(:id)
    end


  end








  def self.find_no_projectrom_by_version
    ids = []
    find_by_sql("SELECT VersionId,AppName,AppVersion,a.AppId FROM `version` a,App b WHERE a.AppId=b.AppId AND (a.appid=0 OR 0=0) ORDER BY AppVersion").each do |version|
      ids << version.VersionId if self.find_by_sql("SELECT DISTINCT c.RomId,RomName,c.ProjectId,ProjectName,CR,b.versionid
       FROM AppVersion a,VERSION b,ProjectRom c,Project d,romappversion e
       WHERE a.versionid=b.versionid AND e.RomId=c.RomId
       AND c.ProjectId=d.ProjectId AND a.appversionid=e.appversionid
       AND b.versionid = #{version.VersionId}
       ORDER BY c.ProjectId,RomId").blank?
    end
    ids
  end

  def self.import_project
    find_by_sql("SELECT project.ProjectName,project.ExternalName,projectrom.SPM,projectrom.SQA,projectrom.TestLeader,projectrom.DriverLeader,projectrom.SWLeader FROM projectrom
        INNER JOIN project ON project.ProjectId = projectrom.ProjectId").map { |p|
      {:name => p.ProjectName,:ext_name => p.ExternalName,:spm => p.SPM,:sqa => p.SQA,:test_leader => p.TestLeader,:driver_leader => p.DriverLeader,:sw_leader => p.SWLeader}
    }
  end

  def self.import_app_verion(with_spec = true)
    find_by_sql("SELECT app.AppName,`version`.appversion FROM `version`
        INNER JOIN app ON `version`.appid = app.AppId WHERE `version`.appversion #{with_spec ? '' : 'NOT'} LIKE '%_V%' ORDER BY app.AppId").map { |app_version|
      {:appname => app_version.AppName, :appversion => app_version.appversion}
    }
  end

  def self.data_to_amige
    find_by_sql(self.sql).map { |row|
      {
          :project_name => row.project_name,
          :project_identify => row.project_identify,
          :project_spec => row.project_spec,
          :project_spec_desc => row.project_spec_desc,
          :project_spm => row.project_spm,
          :project_sqa => row.project_sqa,
          :project_sw => row.project_sw,
          :project_dl => row.project_dl,
          :project_test => row.project_test,
          :package_repo => row.package_repo,
          :release_cc => row.release_cc,
          :app_name => row.app_name,
          :app_spec_version => row.app_spec_version,
          :apk_repo => row.apk_repo,
          :version_cc => row.version_cc
      }
    }
  end

  def self.sql
    "SELECT
      project.ProjectName          project_name,
      project.ExternalName         project_identify,
      projectrom.RomName           project_spec,
      projectrom.RomDesc           project_spec_desc,
      projectrom.SPM               project_spm,
      projectrom.SQA               project_sqa,
      projectrom.SWLeader          project_sw,
      projectrom.DriverLeader      project_dl,
      projectrom.TestLeader        project_test,
      projectrom.SVNPaths          package_repo,
      projectrom.Emails            release_cc,
      app.AppName                  app_name,
      appversion.AppVersionName    app_spec_version,
      appversion.BranchPath        apk_repo,
      appversion.Emails            version_cc
    FROM projectrom
      INNER JOIN project
        ON project.ProjectId = projectrom.ProjectId
      LEFT JOIN romappversion
        ON projectrom.RomId = romappversion.RomId
      LEFT JOIN appversion
        ON appversion.AppVersionId = romappversion.AppVersionId
      INNER JOIN app
        ON app.AppId = appversion.AppId
    ORDER BY project.ProjectId,projectrom.RomId"
  end

  # PerPage pages
  PER_PAGE = 25

  class Original
    def self.bug_amount_with_time(sql)
      reg = /assigned_to_id in \((.*?)\)/i
      reg.match(sql)
      sql1 = "1=1"
      sql1 = "iss.assigned_to_id in (#{$1})" if $1
      sql = sql.gsub("assigned_to_id in (#{$1}) and", "") if $1

      "SELECT * FROM (SELECT * FROM ((SELECT
          issues.id         AS iid,
          issues.created_on,
          SUBSTRING_INDEX(GROUP_CONCAT(journal_details.old_value),',',1) AS assigned_to_id
        FROM issues
          LEFT JOIN journals
            ON journals.journalized_id = issues.id
              AND journals.journalized_type = 'Issue'
          LEFT JOIN journal_details
            ON journal_details.journal_id = journals.id
          LEFT JOIN custom_values AS cf2
            ON cf2.customized_id = issues.id
              AND cf2.custom_field_id = 2
              AND cf2.customized_type = 'Issue'
          LEFT JOIN enumerations AS probability
            ON probability.id = issues.priority_id
              AND probability.type = 'IssuePriority'
          LEFT JOIN custom_values AS cf5
            ON cf5.customized_id = issues.id
              AND cf5.custom_field_id = 5
              AND cf5.customized_type = 'Issue'
          LEFT JOIN users
            ON users.id = journal_details.old_value
              AND journal_details.prop_key = 'assigned_to_id'
          LEFT JOIN depts
            ON users.orgNo = depts.orgNo
          LEFT JOIN projects
            ON issues.project_id = projects.id
          LEFT JOIN mokuais
            ON mokuais.id = issues.mokuai_name
        WHERE #{sql.gsub('<','>')}
            AND journal_details.prop_key = 'assigned_to_id'
            AND journal_details.old_value IS NOT NULL
        GROUP BY issues.id
        ORDER BY issues.id,journals.created_on)
        UNION
        (SELECT
          issues.id         AS iid,
          issues.created_on,
          '' AS assigned_to_id
        FROM issues
          LEFT JOIN journals
            ON journals.journalized_id = issues.id
              AND journals.journalized_type = 'Issue'
          LEFT JOIN journal_details
            ON journal_details.journal_id = journals.id
          LEFT JOIN custom_values AS cf2
            ON cf2.customized_id = issues.id
              AND cf2.custom_field_id = 2
              AND cf2.customized_type = 'Issue'
          LEFT JOIN enumerations AS probability
            ON probability.id = issues.priority_id
              AND probability.type = 'IssuePriority'
          LEFT JOIN custom_values AS cf5
            ON cf5.customized_id = issues.id
              AND cf5.custom_field_id = 5
              AND cf5.customized_type = 'Issue'
        WHERE #{sql}
        GROUP BY issues.id
        HAVING IFNULL(FIND_IN_SET('assigned_to_id',GROUP_CONCAT(journal_details.prop_key)),0) = 0
        ORDER BY issues.id,journals.created_on)) AS issue
        GROUP BY issue.iid
        ORDER BY issue.iid) AS iss
        WHERE #{sql1}"
    end

    def self.bug_amount(feilds, times, sql, sql1, sql3, ids_with_time, group_by, order_by)
      <<~MYSQL
        SELECT #{feilds},COUNT(DISTINCT issues.id) AS amount,'[]' AS cons,'' AS opts#{times} FROM ((SELECT
          issues.id AS iid,SUBSTRING_INDEX(GROUP_CONCAT(journals.created_on),',',-1) AS countTime,SUBSTRING_INDEX(GROUP_CONCAT(journal_details.value),',',-1) AS assigned_to_id
        FROM issues
        LEFT JOIN journals ON journals.journalized_id = issues.id AND journals.journalized_type = 'Issue'
        LEFT JOIN journal_details ON journal_details.journal_id = journals.id
        LEFT JOIN custom_values AS cf2 ON cf2.customized_id = issues.id AND cf2.custom_field_id = 2 AND cf2.customized_type = 'Issue'
        LEFT JOIN enumerations AS probability ON probability.id = issues.priority_id AND probability.type = 'IssuePriority'
        LEFT JOIN custom_values AS cf5 ON cf5.customized_id = issues.id AND cf5.custom_field_id = 5 AND cf5.customized_type = 'Issue'
        LEFT JOIN users ON users.id = journal_details.value
        LEFT JOIN depts ON users.orgNo = depts.orgNo
        LEFT JOIN projects ON issues.project_id = projects.id
        LEFT JOIN mokuais ON mokuais.id = issues.mokuai_name
        WHERE #{sql1} AND journal_details.prop_key = 'assigned_to_id'
        GROUP BY issues.id
        ORDER BY issues.id,journals.created_on)
        UNION
        (SELECT issues.id AS iid,issues.created_on,issues.assigned_to_id
        FROM issues
        LEFT JOIN journals ON journals.journalized_id = issues.id AND journals.journalized_type = 'Issue'
        LEFT JOIN journal_details ON journal_details.journal_id = journals.id
        LEFT JOIN custom_values AS cf2 ON cf2.customized_id = issues.id AND cf2.custom_field_id = 2 AND cf2.customized_type = 'Issue'
        LEFT JOIN enumerations AS probability ON probability.id = issues.priority_id AND probability.type = 'IssuePriority'
        LEFT JOIN custom_values AS cf5 ON cf5.customized_id = issues.id AND cf5.custom_field_id = 5 AND cf5.customized_type = 'Issue'
        LEFT JOIN users ON users.id = issues.assigned_to_id
        LEFT JOIN depts ON users.orgNo = depts.orgNo
        LEFT JOIN projects ON issues.project_id = projects.id
        LEFT JOIN mokuais ON mokuais.id = issues.mokuai_name
        WHERE #{sql}
        GROUP BY issues.id
        HAVING IFNULL(FIND_IN_SET('assigned_to_id',GROUP_CONCAT(journal_details.prop_key)),0) = 0
        ORDER BY issues.id)
        UNION (#{ids_with_time})) AS issue
        INNER JOIN issues on issue.iid = issues.id
        LEFT JOIN custom_values AS cf2 ON cf2.customized_id = issues.id AND cf2.custom_field_id = 2 AND cf2.customized_type = 'Issue'
        LEFT JOIN enumerations AS probability ON probability.id = issues.priority_id AND probability.type = 'IssuePriority'
        LEFT JOIN custom_values AS cf5 ON cf5.customized_id = issues.id AND cf5.custom_field_id = 5 AND cf5.customized_type = 'Issue'
        LEFT JOIN users ON users.id = issue.assigned_to_id
        LEFT JOIN depts ON users.orgNo = depts.orgNo
        LEFT JOIN projects ON issues.project_id = projects.id
        LEFT JOIN mokuais ON mokuais.id = issues.mokuai_name
        WHERE #{sql3}
        GROUP BY #{group_by}
        ORDER BY #{order_by}
      MYSQL
    end
  end

  class Personalize
    def self.leave_times_and_rate_sql(sql)
      "SELECT * FROM (
        (SELECT
        issues.id AS iid,issues.assigned_to_id,journals.user_id,
        journal_details.prop_key,journal_details.old_value,journal_details.value,
        issues.updated_on AS issue_updated_on,journals.created_on AS journal_created_on,
        CASE WHEN journal_details.prop_key = 'assigned_to_id' AND journal_details.value = issues.assigned_to_id THEN journals.created_on ELSE issues.updated_on END AS times
        FROM issues
        LEFT JOIN journals ON journals.journalized_id = issues.id
        LEFT JOIN journal_details ON journal_details.journal_id = journals.id
        WHERE issues.status_id IN (7,8,9,10) #{sql}
        GROUP BY issues.id
        HAVING COUNT(journals.id) = 1
        ORDER BY issues.created_on,journals.created_on,issues.id)
        UNION ALL
        (SELECT
        issues.id AS iid,issues.assigned_to_id,journals.user_id,
        journal_details.prop_key,journal_details.old_value,journal_details.value,
        issues.updated_on AS issue_updated_on,journals.created_on AS journal_created_on,
        CASE WHEN journal_details.prop_key = 'assigned_to_id' AND journal_details.value = issues.assigned_to_id THEN journals.created_on ELSE issues.updated_on END AS times
        FROM issues
        LEFT JOIN journals ON journals.journalized_id = issues.id
        LEFT JOIN journal_details ON journal_details.journal_id = journals.id
        WHERE issues.status_id IN (7,8,9,10) #{sql}
        AND journals.created_on IS NULL
        ORDER BY issues.created_on,journals.created_on,issues.id)) AS iss"
    end

    def project_spec_version_same_production
      project_spec_production_versions = []
      Spec.joins(:projects).where("projects.category <> 4").each do |spec|
        project_spec_production_versions << spec.id unless SpecVersion.select("spec_versions.spec_id,production_id,COUNT(spec_versions.id) amount").where("spec_id = #{spec.id} and deleted = 0").group("production_id").having("amount > 1").map{|app| app.production_id}.blank?
      end
      project_spec_production_versions.map { |spec_id| {:project_name => Project.find(Spec.find(spec_id).project_id).name, :spec_name => Spec.find(spec_id).name, :production_name => Project.where(:id => SpecVersion.select("spec_versions.spec_id,spec_versions.production_id,COUNT(spec_versions.id) amount").where("spec_id = #{spec_id}").group("production_id").having("amount > 1").map { |app| app.production_id }).map { |p| p.name }} }

      [{:project_name=>"SW17G03A", :spec_name=>"amigo4.0", :production_name=>["Amigo_GSP"]},
       {:project_name=>"WBL7517A_taste_17041", :spec_name=>"amigo4.0", :production_name=>["Ami_Weather"]},
       {:project_name=>"BBL7505A", :spec_name=>"amigo3.1", :production_name=>["Amigo_StoryLocker", "Amigo_SystemUI", "Amigo_Changer", "Amigo_GSP", "GN_Gou", "Amigo_SystemManager", "Amigo_Calculator", "Amigo_Search", "Amigo_Mms", "Amigo_Contacts", "Amigo_FileManager", "Amigo_DataGhost", "Amigo_Account", "Amigo_RingTone", "Amigo_Travel", "Amigo_Browser", "Amigo_SettingUpdate", "Amigo_CustomerHelper", "GN_Push", "Ami_Calendar", "GN_MMI", "GN_AutoMMI", "Amigo_CarefreeLauncher", "Amigo_Wifi_Settings", "Amigo_Chameleon", "Amigo_ColorfulLiveWallpaper", "Amigo_Music", "Amigo_GameHall"]},
       {:project_name=>"GBL7359A", :spec_name=>"amigo3.1", :production_name=>["Amigo_Browser"]},
       {:project_name=>"GBL7356A", :spec_name=>"amigo3.1", :production_name=>["Amigo_Browser"]},
       {:project_name=>"GBL7358A", :spec_name=>"amigo3.1", :production_name=>["Amigo_Browser", "Amigo_Video"]},
       {:project_name=>"GBL7523A", :spec_name=>"amigo3.1", :production_name=>["Amigo_Browser", "Amigo_Music"]},
       {:project_name=>"BBL7332A", :spec_name=>"amigo3.1", :production_name=>["Amigo_StoryLocker", "Amigo_SystemManager"]},
       {:project_name=>"GBL8608", :spec_name=>"ROM4.2.10", :production_name=>["Amigo_Changer", "Amigo_Service", "GN_Gou", "Amigo_SystemManager", "Amigo_PackageInstaller", "Amigo_Account", "Amigo_AntiStolen", "Amigo_Browser", "Amigo_TelepathClient", "GN_Push", "Amigo_GameHall", "Amigo_Fan_Fan", "Amigo_Navil"]},
       {:project_name=>"CBL8601A", :spec_name=>"ROM4.2.8", :production_name=>["Amigo_Changer", "Amigo_Mms", "Amigo_Contacts", "Amigo_Browser", "Amigo_TelepathClient", "GN_Push", "Amigo_CarefreeLauncher", "Amigo_GameHall"]},
       {:project_name=>"WBT5315A", :spec_name=>"ROM4.2.2", :production_name=>["GN_Gou"]},
       {:project_name=>"GBL7335A", :spec_name=>"amigo3.1", :production_name=>["Amigo_StoryLocker", "Amigo_SystemUI", "Amigo_Changer", "Amigo_GSP", "GN_Gou", "Amigo_SystemManager", "Amigo_Calculator", "Amigo_Search", "Amigo_Mms", "Amigo_Contacts", "Amigo_FileManager", "Amigo_DataGhost", "Amigo_Account", "Amigo_RingTone", "Amigo_Browser", "Amigo_SettingUpdate", "Amigo_CustomerHelper", "GN_Push", "Amigo_Note", "Ami_Calendar", "Ami_Weather", "Amigo_NewGallery", "Amigo_CarefreeLauncher", "Amigo_Wifi_Settings", "Amigo_Chameleon", "Amigo_ColorfulLiveWallpaper", "Amigo_Music", "Amigo_Video", "Amigo_GameHall"]},
       {:project_name=>"CBL7501", :spec_name=>"amigo3.0", :production_name=>["Amigo_Service", "GN_Gou", "Amigo_Calculator", "Amigo_FileManager", "Amigo_DeskClock", "Amigo_Synchronizer", "Amigo_AntiStolen", "Amigo_Browser", "Amigo_Note", "Ami_Weather", "Amigo_NewGallery", "Amigo_CarefreeLauncher", "Amigo_Wifi_Settings", "Amigo_Music", "Amigo_Video", "Amigo_NaviKeyguard"]},
       {:project_name=>"CBT5701", :spec_name=>"ROM4.4.15", :production_name=>["Amigo_Changer", "Ami_Weather", "Amigo_GameHall"]},
       {:project_name=>"WBW5885_Taste3.3", :spec_name=>"amigo2.4.20", :production_name=>["Amigo_SystemUI", "Amigo_DeskClock", "Amigo_NewGallery", "Amigo_Wifi_Settings", "Amigo_Bluetooth", "Amigo_AppSipper", "Amigo_Camera", "Amigo_Navil", "Amigo_NaviKeyguard"]},
       {:project_name=>"WBW5885", :spec_name=>"ROM4.2.7", :production_name=>["Amigo_Service", "GN_Gou", "Amigo_PackageInstaller", "Amigo_Account", "Amigo_AntiStolen", "Amigo_ShortcutTools", "Amigo_DymanicWeather"]},
       {:project_name=>"WBW5885", :spec_name=>"ROM4.2.4", :production_name=>["Amigo_VoiceHelper"]},
       {:project_name=>"GBT8903A", :spec_name=>"ROM4.2.11", :production_name=>["Amigo_Settings"]}]
    end
  end

end
