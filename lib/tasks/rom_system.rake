namespace :rom_system do
  desc 'Add data to projects'
  task :create_projects_if_not_exist => :environment do
    projects = Project.find_by_sql(project_sql)
    projects.each do |p|
      pname = p.project_name
      if pname
        project = Project.find_by_name pname
        create_members_and_projects(p) if project.blank?
      end
    end
  end

  desc 'Add data to projects'
  task :add_data_to_projects => :environment do
    projects = Project.find_by_sql(project_sql)

    projects.each do |p|
      pname = p.project_name
      if pname
        project = Project.find_by_name pname
        create_members_and_projects(p) if project.blank?

        project = Project.find_by_name pname
        project_spec_name = p.project_spec.to_s
        project_spec = Spec.find_by_project_id_and_name_and_deleted(project.id, project_spec_name, 0)
        Spec.create({:name => project_spec_name, :project_id => project.id, :note => p.project_spec_desc, :for_new => false}) if project_spec.blank?

        # create production
        to_s = p.app_name.to_s
        app_name = to_s
        if app_name
          production = Production.find_by_name(app_name.to_s)
          Project.create({:name => app_name, :production_type => ["Framework", "framework"].include?(app_name) ? 3 : 1, :identifier => app_name.to_s.downcase, :ownership => 1, :category => '4'}) if production.blank?

          production = Production.find_by_name(app_name.to_s)
          app_spec_version_name = p.app_spec_version.to_s.split('_V') if p.app_spec_version.to_s.include?('_V')
          app_spec_version_name = p.app_spec_version.to_s.split('_v') if p.app_spec_version.to_s.include?('_v')
          app_spec_name = app_spec_version_name[0].strip
          # Create app_spec
          app_spec = Spec.find_by_project_id_and_name_and_deleted(production.id, app_spec_name, 0)
          Spec.create({:name => app_spec_name, :project_id => production.id, :for_new => false}) if app_spec.blank?

          app_spec = Spec.find_by_project_id_and_name_and_deleted(production.id, app_spec_name, 0)
          app_version_name = 'V' + app_spec_version_name[1].strip
          app_version = Version.find_by_project_id_and_name_and_spec_id(production.id, app_version_name, app_spec.id)

          Version.create({:project_id => production.id, :spec_id => app_spec.id, :name => app_version_name, :status => 1, :priority => 3, :arm => 32, :strengthen => false, :unit_test => false, :auto_test => false, :sonar_test => false}) if app_version.blank?

          app_version = Version.find_by_project_id_and_name_and_spec_id(production.id, app_version_name, app_spec.id)
          puts "=======#{project.name}---#{production.name}---#{app_version.name}======"
          spec_version = SpecVersion.find_by_production_id_and_spec_id_and_version_id(production.id, project_spec.id, app_version.id)
          if spec_version.blank?
            sv = SpecVersion.new
            sv.spec_id = project_spec.id
            sv.production_id = production.id
            sv.version_id = app_version.id
            sv.release_path = p.apk_repo
            sv.save
          end
        end
      end
    end
  end

  desc 'Import data to version_release'
  task :import_data_to_version_release => :environment do
    no_ids = []
    last_insert_ids = []
    releases = Project.find_by_sql(version_release_sql)

    releases.each do |r|
      app = Production.find_by_name(r.app_name)
      unless app.blank?
        spec_version = r.spec_version.to_s.split('_V') if r.spec_version.to_s.include?('_V') # "03_V1.1.1.b"
        spec_version = r.spec_version.to_s.split('_v') if r.spec_version.to_s.include?('_v') # "03_V1.1.1.b"
        spec_name = spec_version[0].to_s.strip
        version_name = spec_version[1].to_s.strip
        app_spec = Spec.find_by_name_and_project_id(spec_name,app.id)
        unless app_spec.blank?
          main_version_name = version_name.gsub(".#{version_name.to_s.split('.')[-1]}", "")
          main_version = Version.where("project_id = #{app.id} and spec_id = #{app_spec.id}
                  and name like 'V#{main_version_name}%' and parent_id is null").order("created_on desc")

          unless main_version.blank?
            version = Version.find_by_project_id_and_name_and_spec_id_and_parent_id(app.id, version_name, app_spec.id, main_version.first.id)
            if version.blank?
              sql = "INSERT INTO `versions` (`project_id`, `name`, `description`, `created_on`, `updated_on`, `sharing`, `production_name`, `compile_status`, `spec_id`, `parent_id`, `unit_test`)
                              VALUES('#{app.id}','#{version_name}','Virtual version', '#{Time.now.to_s(:db)}', '#{Time.now.to_s(:db)}','1','none', '6', '#{app_spec.id}', '#{main_version.first.id}', 0);"
              ActiveRecord::Base.connection.execute(sql)
              version = Version.find_by_project_id_and_name_and_spec_id_and_parent_id(app.id, version_name, app_spec.id, main_version.first.id)
              unless version.blank?
                release_attribute = JSON.parse(r.to_json).to_h
                release_attribute.delete("id")
                release_attribute.delete("appid")
                release_attribute.delete("app_name")
                release_attribute.delete("spec_version")
                release_attribute.delete("file_name")
                release_attribute.delete("created_on")
                release_attribute.delete("is_sqa")
                release_attribute.delete("is_ued")
                release_attribute["version_id"] = version.id
                VersionRelease.create(release_attribute)
                puts "============#{release_attribute}============"
              end
            end
          end
        end
      end
    end
  end

  desc 'Report data to env repos'
  task :report_env_repos => :environment do
    repos = "ssh://gerritroot@19.9.0.146:29418/googlesource_android-5.0.0_r1/master,ssh://gerritroot@19.9.0.146:29418/googlesource_android-5.1.0_r1/master,ssh://gerritroot@19.9.0.146:29418/googlesource_android-6.0.0_r1/master,ssh://gerritroot@19.9.0.146:29418/googlesource_android-7.0.0_r1/master"
    repos.split(",").each do |repo|
      r = Repo.find_by_url(repo)
      if r.blank?
        new_repo = Repo.new
        new_repo.url = repo
        new_repo.url_type = 1
        new_repo.author_id = 1
        new_repo.category = Repo.consts[:category][:env]
        puts "=======ok:#{new_repo.id}=======" if new_repo.save
      end
    end
  end

  desc 'Report data to production repos'
  task :report_production_repos => :environment do
    repos = "ssh://gerritroot@19.9.0.146:29418/modem_mtk_m_6755_66_c2k_mp3/branch_gbl7553_c2k_t0064_p18_rel
ssh://gerritroot@19.9.0.146:29418/modem_mtk_m_6755_66_c2k_mp3/master
ssh://gerritroot@19.9.0.146:29418/modem_mtk_m_6755_66_lte_mp3/branch_gbl7553_gbl7558_lte_p58_rel
ssh://gerritroot@19.9.0.146:29418/modem_mtk_m_6755_66_lte_mp3/branch_gbl7553_t0080_rel
ssh://gerritroot@19.9.0.146:29418/modem_mtk_m_6755_66_lte_mp3/master
ssh://gerritroot@19.9.0.146:29418/modem_mtk_n_6737m_65_a_lte_mp/master
ssh://gerritroot@19.9.0.146:29418/modem_mtk_n_6737m_65_lte_mp/master
ssh://gerritroot@19.9.0.146:29418/modem_mtk_n_6755_66_c2k_mp/master
ssh://gerritroot@19.9.0.146:29418/modem_mtk_n_6755_66_c2k_mp7/master
ssh://gerritroot@19.9.0.146:29418/modem_mtk_n_6755_66_lte_mp/master
ssh://gerritroot@19.9.0.146:29418/modem_mtk_n_6755_66_lte_mp7/master
ssh://gerritroot@19.9.0.146:29418/modem_mtk_n_6757_66_mp5_c2k_mp/master
ssh://gerritroot@19.9.0.146:29418/modem_mtk_n_6757_66_mp5_lte_mp/master
ssh://gerritroot@19.9.0.146:29418/modem_qc_m_qct8976_cs/branch_gbl8918_t3451
ssh://gerritroot@19.9.0.146:29418/modem_qc_m_qct8976_cs/branch_gbl8918_t5070_gms
ssh://gerritroot@19.9.0.146:29418/modem_qc_m_qct8976_cs/branch_gbl8918_t5070_rel
ssh://gerritroot@19.9.0.146:29418/modem_qc_m_qct8976_cs/branch_gbl8918_t7020_rel
ssh://gerritroot@19.9.0.146:29418/modem_qc_m_qct8976_cs/master
ssh://gerritroot@19.9.0.146:29418/modem_qc_m_qct8976_study2/master
ssh://gerritroot@19.9.0.146:29418/modem_qc_m_qct8976_study2/modem_qc_m_qct8976_es3
ssh://gerritroot@19.9.0.146:29418/modem_qc_m_qct8976_study2/modem_qc_m_qct8976_pre_cs
ssh://gerritroot@19.9.0.146:29418/modem_qc_n_qrd8920_cs/master"
    repos.split("\n").each do |repo|
      r = Repo.find_by_url(repo)
      if r.blank?
        new_repo = Repo.new
        new_repo.url = repo
        new_repo.url_type = 1
        new_repo.author_id = 1
        new_repo.category = Repo.consts[:category][:production]
        puts "=======ok:#{new_repo.id}=======" if new_repo.save
      end
    end
  end

  desc 'Report data to android repos'
  task :report_android_repos => :environment do
    repos = "ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6750_k50v1_66_pre/master
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7332_t4070_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7332_t4341_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7332_t4524_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_BBL7332_T4538_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7332_t4563_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7332_t4613_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7332_t4757_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7332_t4759_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7332_t4776_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7332_t4790_ningxia
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7332_t4840_test_patch
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7332_t4920_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7332_t4929_cts_test
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7505_t3209_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7505_t3259_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7505_t3265_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7505_t3390_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7505_t3405_rel_xinjiang
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7505_t3665_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_bbl7505_t3713_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_cbl7513_t1656_test
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7333_t3100_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7335_t3129_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7356_t0807_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_GBL7356_T3040_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7356_t3065_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7356_t3071_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7356_t3151_shandong
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7358_CUTest_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7358_t0905_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7358_t3074_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7358_t3097_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7358_t3540_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7358_t3568_cu_test
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7359_t0812_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7359_t3062_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7359_t3065_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7359_t3071_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7359_t3134_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7359_t3136_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/branch_gbl7370_t0526_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/master
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6753_65c_mp3/master_ci
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6755_66_mp/branch_gbl7523_t0921_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6755_66_mp/branch_gbl7523_t2060_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6755_66_mp/branch_gbl7523_t2096_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6755_66_mp/branch_gbl7523_t2127_jiangxi
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6755_66_mp/branch_gbl7523_t2127_xinjiang
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6755_66_mp/branch_gbl7523_t2158_ningxia
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6755_66_mp/branch_gbl7523_t2542_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_l_6755_66_mp/master
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6580_mp1/master
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6595_mp18/branch_oversea_wbl5708_t5392_20161125_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6595_mp18/master
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6735_65t_mp/master
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_gbl7370_t0526_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_gbl7370_t2021_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_gbl7370_t2055_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_gbl7370_t2081_hezuoku
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_gbl7370_t2081_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_gbl7370_t2097_neimeng
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_gbl7370_t2097_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_gbl7370_t2575_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_gbl7370_t3503_test
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_oversea_wbl7365_wbl7361_t5276_patch_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_oversea_wbl7365_wbl7361_t5461_20161024_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_oversea_wbl7372_wbl7362_wbl7375_T5163_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_sw17g03_t0335_cmcc
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_sw17g03_t0335_cmcc.xml
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_sw17g03_t0514_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_swg1613_T0311_gms
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_swg1613_t0409_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_swg1613_t2057_xinjiang
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_swg1613_t2059_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/branch_swg1613_t2064_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/master
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6737_mp1/scm_test
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6750_mp7_by/master
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6753_65t_mp1/branch_oversea_gbl7325_gbl7360_wbl7519_wbl7355_t5478_temp_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6753_65t_mp1/branch_oversea_gbl7325_gbl7360_wbl7519_wbl7355_t5738_patch_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6753_65t_mp1/branch_oversea_gbl7325_gbl7360_wbl7519_wbl7355_t6164_20170321_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6753_65t_mp1/branch_oversea_gbl7325_gbl7360_wbl7519_wbl7355_t6386_20170110_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6753_65t_mp1/branch_oversea_gbl7325_gbl7360_wbl7519_wbl7519_t5989_allinone_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6753_65t_mp1/branch_oversea_wbl7511_t8174_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6753_65t_mp1/master
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_gbl7529_t0306_test
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_gbl7529_t0519_cms
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_gbl7529_t0537_sec
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_gbl7529_t0542_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_gbl7529_t2015_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_GBL7529_t2063_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_gbl7529_t2103_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_gbl7529a01_a_cta_t0151
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_oversea_gbl7325_gbl7360_wbl7519_wbl7355_t6386_20170110_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_oversea_gbl7533_t5445_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_oversea_gbl7533_t5909_20161026_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_wbl7517_oversea_t5200_mwc
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_wbl7517_t1059_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_wbl7517_t1065_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_wbl7517_t2033_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_WBL7517_T2062_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_wbl7517_t2080_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_wbl7517_t2109_test
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_wbl7517_t2134_xinjiang
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_wbl7517_t2145
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_wbl7517_t2145_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_wbl7517_wbl7531_t5382_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_wbl7517_wbl7531_t5459_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_wbl7517_wbl7531_t5477_20170123_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/branch_wbl7517_wbl7531_t5621_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mp/master
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_66_mpbranch_wbl7517_wbl7531_t5477_20170123_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/branch_gbl7553_t0166_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/branch_gbl7553_t0183_test
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/branch_gbl7553_t0614_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/branch_gbl7553_t0661_cu_test
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/branch_gbl7553_t0703_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/branch_gbl7553_t2068_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/branch_gbl7553_t2068_tmp_taiwan
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/branch_gbl7553_t2093_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/branch_gbl7553_t2093_xinjiang
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/branch_gbl7553_t2109_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/branch_oversea_gbl7558_t5150_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/branch_oversea_gbl7558_t5562_20170307_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/branch_swg1608_t0137_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/branch_swg1608_t0248_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/branch_swg1608_t0503_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/branch_swg1608_t2034_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/branch_swg1608_t2057_xinjiang
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/branch_swg1608_t2091_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_c66_mp/master
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_mp_by/branch_bbl7551_t5536_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6755_mp_by/master
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_6797_6c_mp2/master
ssh://gerritroot@19.9.0.151:29418/android_mtk_m_K35V1_64_OP01_PRE/master
ssh://gerritroot@19.9.0.151:29418/android_mtk_n_6580_mp2/master
ssh://gerritroot@19.9.0.151:29418/android_mtk_n_6737M_65_A_mp1/master
ssh://gerritroot@19.9.0.151:29418/android_mtk_n_6737m_65_mp1/branch_SW17G09_t5089_pre
ssh://gerritroot@19.9.0.151:29418/android_mtk_n_6737m_65_mp1/master
ssh://gerritroot@19.9.0.151:29418/android_mtk_n_6755_66_mp/branch_gbl7529_t3224_test
ssh://gerritroot@19.9.0.151:29418/android_mtk_n_6755_66_mp/branch_gbl7553_t2068_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_n_6755_66_mp/branch_oversea_SWW1609_t5390_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_n_6755_66_mp/branch_oversea_SWW1609_t5831_20170311_temp
ssh://gerritroot@19.9.0.151:29418/android_mtk_n_6755_66_mp/master
ssh://gerritroot@19.9.0.151:29418/android_mtk_n_6757_66_mp5/branch_oversea_sww1617_t5123_rel
ssh://gerritroot@19.9.0.151:29418/android_mtk_n_6757_66_mp5/master
ssh://gerritroot@19.9.0.151:29418/android_qc_l_qrd8939_cs/master
ssh://gerritroot@19.9.0.151:29418/android_qc_m_qct8976_cs/branch_gbl8918_t0503_test
ssh://gerritroot@19.9.0.151:29418/android_qc_m_qct8976_cs/branch_gbl8918_t0606_test
ssh://gerritroot@19.9.0.151:29418/android_qc_m_qct8976_cs/branch_gbl8918_T1017_gms
ssh://gerritroot@19.9.0.151:29418/android_qc_m_qct8976_cs/branch_gbl8918_t1111_rel
ssh://gerritroot@19.9.0.151:29418/android_qc_m_qct8976_cs/branch_gbl8918_t2039_buzhan
ssh://gerritroot@19.9.0.151:29418/android_qc_m_qct8976_cs/branch_gbl8918_t2047_tencent
ssh://gerritroot@19.9.0.151:29418/android_qc_m_qct8976_cs/branch_gbl8918_t2071_rel
ssh://gerritroot@19.9.0.151:29418/android_qc_m_qct8976_cs/master
ssh://gerritroot@19.9.0.151:29418/android_qc_m_qct8976_study/master
ssh://gerritroot@19.9.0.151:29418/android_qc_m_qct8976_study1/master
ssh://gerritroot@19.9.0.151:29418/android_qc_m_qct8976_study2/android_qc_m_qct8976_es3
ssh://gerritroot@19.9.0.151:29418/android_qc_m_qct8976_study2/android_qc_m_qct8976_pre_cs
ssh://gerritroot@19.9.0.151:29418/android_qc_m_qct8976_study2/master
ssh://gerritroot@19.9.0.151:29418/android_qc_n_qrd8920_cs/master"
    repos.split("\n").each do |repo|
      r = Repo.find_by_url(repo)
      if r.blank?
        new_repo = Repo.new
        new_repo.url = repo
        new_repo.url_type = 1
        new_repo.author_id = 1
        new_repo.category = Repo.consts[:category][:android]
        puts "=======ok:#{new_repo.id}=======" if new_repo.save
      end
    end
  end

  desc 'Report data to package repos'
  task :report_package_repos => :environment do
    repos = "ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/GBL7529_branch_gbl7529_t3224_test
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/GBL7529_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/GBL7533_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/GBL7533_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/SW17G01A_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/SW17G02_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/SW17G04_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/SW17W05_branch_SW17G09_t5089_pre
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/SW17W05_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/SWG1610_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/SWW1609_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/SWW1609_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/SWW1609_oversea_stock
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/SWW1616_oversea_stock
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/SWW1617_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/SWW1618_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/SWW1627_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/SWW1631_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo/WBL7519_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.0/CBL7501_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.0/master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t0812_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t0827_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t20160527_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t20160624_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t20160711_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t20160726_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t20160812_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t20160827_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t20161013_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t4070_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t4341_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t4524_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_BBL7332_t4538_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t4563_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t4613_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t4757_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t4759_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t4776_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t4790_ningxia
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_branch_bbl7332_t4920_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7332_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7505_branch_bbl7505_t0812_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7505_branch_bbl7505_t20160527_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7505_branch_bbl7505_t20160624_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7505_branch_bbl7505_t20160711_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7505_branch_bbl7505_t20160726_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7505_branch_bbl7505_t20160812_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7505_branch_bbl7505_t20160827_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7505_branch_bbl7505_t20161013_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7505_branch_bbl7505_t3100_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7505_branch_bbl7505_t3209_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7505_branch_bbl7505_t3259_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7505_branch_bbl7505_t3265_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7505_branch_bbl7505_t3390_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7505_branch_bbl7505_t3405_rel_xinjiang
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7505_branch_bbl7505_t3665_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7505_branch_bbl7505_t3713_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/BBL7505_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/branch_gbl7358_t3568_cu_test
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/branch_gbl7523_t2158_ningxia
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/CBL7320_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/CBL7513_branch_cbl7513_t0812_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/CBL7513_branch_cbl7513_t20160527_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/CBL7513_branch_cbl7513_t20160624_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/CBL7513_branch_cbl7513_t20160711_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/CBL7513_branch_cbl7513_t20160726_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/CBL7513_branch_cbl7513_t20160812_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/CBL7513_branch_cbl7513_t20160827_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/CBL7513_branch_cbl7513_t20161013_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/CBL7513_branch_cbl7513_t3100_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/CBL7513_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/CBL7513_master_ci
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7319_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7333_branch_gbl7333_t0812_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7333_branch_gbl7333_t20160527_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7333_branch_gbl7333_t20160624_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7333_branch_gbl7333_t20160711_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7333_branch_gbl7333_t20160726_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7333_branch_gbl7333_t20160812_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7333_branch_gbl7333_t20160827_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7333_branch_gbl7333_t20161013_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7333_branch_gbl7333_t3100_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7333_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7335_branch_gbl7335_t0812_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7335_branch_gbl7335_t20160527_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7335_branch_gbl7335_t20160624_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7335_branch_gbl7335_t20160711_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7335_branch_gbl7335_t20160726_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7335_branch_gbl7335_t20160812_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7335_branch_gbl7335_t20160827_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7335_branch_gbl7335_t20161013_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7335_branch_gbl7335_t3100_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7335_branch_gbl7335_t3129_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7335_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7356_branch_gbl7356_t0807_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7356_branch_gbl7356_t0812_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7356_branch_gbl7356_t0913_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7356_branch_gbl7356_t20160827_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7356_branch_gbl7356_t20160913_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7356_branch_gbl7356_t20161013_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7356_branch_GBL7356_T3040_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7356_branch_gbl7356_t3058_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7356_branch_gbl7356_t3065_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7356_branch_gbl7356_t3071_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7356_branch_gbl7356_t3151_shandong
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7356_branch_gbl7359_t20160913_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7356_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7358_branch_gbl7358_t0905_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7358_branch_gbl7358_t3074_temp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7358_branch_gbl7358_t3097_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7358_branch_gbl7358_t3540_temp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7358_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7359_branch_gbl7356_t0913_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7359_branch_gbl7356_t3058_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7359_branch_gbl7359_t0812_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7359_branch_gbl7359_t20160827_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7359_branch_gbl7359_t20160913_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7359_branch_gbl7359_t20161013_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7359_branch_gbl7359_t3062_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7359_branch_gbl7359_t3065_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7359_branch_gbl7359_t3071_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7359_branch_gbl7359_t3134_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7359_branch_gbl7359_t3136_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7359_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7523_branch_ci
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7523_branch_gbl7523_t0921_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7523_branch_gbl7523_t20160725_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7523_branch_gbl7523_t20160812_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7523_branch_gbl7523_t20160825_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7523_branch_gbl7523_t20160909_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7523_branch_gbl7523_t2060_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7523_branch_gbl7523_t2096_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7523_branch_gbl7523_t2127_jiangxi
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7523_branch_gbl7523_t2127_xinjiang
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7523_branch_gbl7523_t2158_ningxia
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7523_branch_gbl7523_t2542_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7523_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_3.1/GBL7523_branch_gbl7523_t2542_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/BBL371_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/BBL7337_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/BBL7371_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/BBL7371_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/BBL7551_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/BBL7551_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/BBW7551_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/branch_gbl7370_t2055_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/branch_swg1613_t0409_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/branch_wbl7517_oversea_t5200_mwc
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/branch_wbl7517_t1059_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/branch_wbl7517_t2134_xinjiang
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/CBL7521_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/CBL7521_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7319_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7325_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7325_oversea_master_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7325_oversea_stock_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7360_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7360_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7370_branch_gbl7370_t0526_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7370_branch_gbl7370_t2021_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7370_branch_gbl7370_t2055_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7370_branch_gbl7370_t2081_hezuoku
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7370_branch_gbl7370_t2081_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7370_branch_gbl7370_t2097_neimeng
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7370_branch_gbl7370_t2097_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7370_branch_gbl7370_t2575_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7370_branch_gbl7370_t3503_test
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7370_branch_swg1613_t0409_rell
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7370_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7373_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7529_branch_gbl7529_t0306_test
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7529_branch_gbl7529_t0519_cms
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7529_branch_gbl7529_t0537_sec
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7529_branch_gbl7529_t0542_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7529_branch_gbl7529_t2015_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7529_branch_gbl7529_t20161118_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7529_branch_gbl7529_t20170306_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7529_branch_GBL7529_t2063_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7529_branch_gbl7529_t2103_temp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7529_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7533_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7533_oversea_master_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBl7553_branch_gbl7553_t0166_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7553_branch_gbl7553_t0614_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7553_branch_gbl7553_t0661_cu_test
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7553_branch_gbl7553_t0703_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7553_branch_gbl7553_t0703_rel_temp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7553_branch_gbl7553_t2068_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7553_branch_gbl7553_t2068_tmp_taiwan
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7553_branch_gbl7553_t2093_temp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7553_branch_gbl7553_t2093_xinjiang
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7553_branch_gbl7553_t2109_temp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7553_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7553_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL7558_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL8918_branch_gbl8918_t0503_test
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL8918_branch_gbl8918_t0606_test
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL8918_branch_gbl8918_T1017_gms
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL8918_branch_gbl8918_t1111_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL8918_branch_gbl8918_t2039_buzhan
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL8918_branch_gbl8918_t2047_tencent
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL8918_branch_gbl8918_t2071_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBL8918_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/GBW7533_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SW17G03_branch_sw17g03_t0335_cmcc
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SW17G03_branch_sw17g03_t0335_cmcc.xml
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SW17G03_branch_sw17g03_t0514_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SW17G03_branch_swg1613_T0311_gms
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SW17G03_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SW17G11_branch_sw17G11_t0526_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SWG1608_branch_swg1608_t0137_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SWG1608_branch_swg1608_t0248_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SWG1608_branch_swg1608_t0503_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SWG1608_branch_swg1608_t2034_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SWG1608_branch_swg1608_t2057_xinjiang
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SWG1608_branch_swg1608_t2091_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SWG1608_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SWG1613_branch_swg1613_T0311_gms
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SWG1613_branch_swg1613_t0409_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SWG1613_branch_swg1613_t2057_xinjiang
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SWG1613_branch_swg1613_t2059_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SWG1613_branch_swg1613_t2064_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/SWG1613_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/TST6755_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL5708_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL5708_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7355_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7355_oversea_master_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7355_oversea_stock_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7361_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7361_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7362_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7362_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7365_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7365_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7369_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7369_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7372_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7372_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7375_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7511_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7511_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7517_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7517_branch_wbl7517_t0542_temp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7517_branch_wbl7517_t1059_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7517_branch_wbl7517_t1065_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7517_branch_wbl7517_t20161118_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7517_branch_wbl7517_t20170306_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7517_branch_wbl7517_t2033_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7517_branch_WBL7517_T2062_rel
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7517_branch_wbl7517_t2080_temp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7517_branch_wbl7517_t2109_test
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7517_branch_wbl7517_t2134_xinjiang
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7517_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7517_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7519_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7519_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7531_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBL7531_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBW5615_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBW5615_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBW5616_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBW5616_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBW5618_oversea_master
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBW5620_branch_oversea_mp
ssh://gerritroot@19.9.0.151:29418/gionee_packages_apk_amigo_4.0/WBW5620_oversea_master"
    repos.split("\n").each do |repo|
      r = Repo.find_by_url(repo)
      if r.blank?
        new_repo = Repo.new
        new_repo.url = repo
        new_repo.url_type = 1
        new_repo.author_id = 1
        new_repo.category = Repo.consts[:category][:package]
        puts "=======ok:#{new_repo.id}=======" if new_repo.save
      end
    end
  end

  def create_members_and_projects(p)
    pro = Project.new
    pro.name = p.project_name
    pro.identifier = p.project_name.to_s.downcase
    pro.category = "1"
    pro.external_name = p.project_identify
    pro.hardware_group = "深研"
    pro.mokuai_class = 1
    pro.ownership = 1
    pro.product_serie = "M系列"

    if pro.save
      spec_module = EnabledModule.find_by_project_id_and_name(pro.id, "specs")
      if spec_module.blank?
        emd = EnabledModule.new
        emd.project_id = pro.id
        emd.name = "specs"
        emd.save
      end

      # Add spms to project
      # add_members_to_project_by_role(pro, p.project_spm, "SPM")

      # Add sqas to project
      # add_members_to_project_by_role(pro, p.project_sqa, "SQA")

      # Add test_leaders to project
      # add_members_to_project_by_role(pro, p.project_test, "测试负责人")

      # Add sw_leaders to project
      # add_members_to_project_by_role(pro, p.project_sw, "软件负责人")

      # Add driver_leaders to project
      # add_members_to_project_by_role(pro, p.project_dl, "平台驱动负责人")
    end
    pro
  end

  def add_members_to_project_by_role(project, users, role_name)
    if users.present?
      members = []
      user_ids = []

      users = users.to_s.include?(",") ? users.to_s.split(",") : users.to_s.split("/")
      users.each do |user|
        user_ids << User.where("firstname like '#{user}%'").first.try(:id)
      end

      user_ids.each do |user_id|
        role = Role.find_by_name(role_name)
        if role.present?
          member = Member.new(:project => project, :user_id => user_id)
          member.set_editable_role_ids(Role.find_by_name(role_name).id)
          members << member
        end
      end
      project.members << members
    end
  end

  def project_sql
    %[
    SELECT *
    FROM project
    WHERE project_name IS NOT NULL
      -- AND project_name IN ('GBT8903A')
      AND app_name like 'Amigo_YingyinTrdApps%'
      AND app_name IS NOT NULL
      AND app_spec_version IS NOT NULL
      AND LOCATE('_V',app_spec_version) > 0
    ]
  end

  def version_release_sql
    %[
    SELECT * FROM apprelease
    ]
  end
end

