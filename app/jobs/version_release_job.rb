class VersionReleaseJob < ActiveJob::Base

  include ReposHelper

  queue_as :release # DON'T CHANGE

  # self.logger = Sidekiq::Logging.logger

  # rescue_from(Exception) do |e|
  #   # puts "VersionReleaseJob#rescue_from #{e}"
  #   retry_job wait: 1.minutes, queue: :default
  # end

  def perform(release_id)
    release = VersionRelease.find(release_id)

    # Change release status to releasing
    release.do_release!

    # check if released overdue
    is_overdue = this_release_is_overdue(release)

    if is_overdue
      release = release.reload
      release.notes = "此版本无法发布，因为已经有更新的小版本发布了，其发布ID： #{is_overdue.id}"
      release.do_complete!
    else
      # Release version (with two thread)
      new_release_thread = Thread.new { new_release(release) } # new_release
      old_release_thread = Thread.new { old_release(release) } # old_release

      new_release_thread.join
      old_release_thread.join

      release = release.reload
      release.do_complete! # change status to completed
    end

    send_released_notification(release) # send email
  end

  def this_release_is_overdue(release)
    return false if release.show_by(3) # not for bugfix
    version_parent_id = release.version.find_parent_id
    pm_version_ids = Version.where("parent_id = ? OR id = ?", version_parent_id, version_parent_id).ids
    latest_release = VersionRelease.completed.where(:version_id => pm_version_ids).order(updated_at: :desc).first

    # compare release and latest_release
    return false unless latest_release

    release_chars = release.version.name[/[a-z]+/].to_s # V2.6.1.abc => abc
    latest_release_chars = latest_release.version.name[/[a-z]+/].to_s

    if latest_release_chars.size < release_chars.size
      return false
    elsif latest_release_chars.size == release_chars.size && latest_release_chars <= release_chars
      return false
    else
      return latest_release
    end
  end

  #------------------ New Release Way ------------------

  def new_release(version_release)
    version_id = version_release.version_id
    version_fullname = version_release.version.fullname
    # find repos that need to update spec.yml
    repos = ReposHelper.get_repos_by_version_id(version_id)
    # repos = repos.find_all { |repo|
    #   repo['project_id'].to_s.in?(version_release.tested_mobile.to_s.split(',').compact.delete_if { |pid| pid.to_s.strip.empty? }) unless repo['project_id'].to_s.strip.empty?
    # }
    repos.each do |r|
      release_path = r['repo_url']
      # Create log folder
      log_folder = version_release.log_folder
      FileUtils.mkdir_p(log_folder) unless Dir.exist?(log_folder)
      log_path = log_folder.join("#{Digest::MD5.hexdigest release_path}.log").to_s
      logger = logger_new log_path, version_release
      begin
        # Check project's platform
        project_platform = r['android_platform'].to_i
        if project_platform == Project::PROJECT_ANDROID_PLATFORM["O平台"].to_i
          fail_msg = []
          version_release.version.app_lists.each do |app|
            o_apk = ApkBase.joins(:project_apk).where("android_platform = #{ApkBase::APK_BASE_ANDROID_PLATFORM[:o_platform]} and name = '#{app.apk_name}' and deleted = 0")
            if o_apk.blank?
              fail_msg << "#{app.apk_name}未经过评审, 不允许发布到#{r['project_name']}项目中。"
            else
              # unless o_apk.count == 1 && o_apk.first.tasks.first.status.to_s == "agreed"
              #   fail_msg << "缺少#{r['production_name']}.apk, 不允许发布到#{r['project_name']}项目中。"
              # end
            end
          end

          if fail_msg.blank?
            logger.info("Get repo by version_id[#{version_id}], #{release_path}")
            git_status = write_spec_to_git(r, logger, version_release.id)
            if git_status[:status] == 0
              release_result_output(version_release, false, {:release_path => git_status[:uri], :log_path => log_path})
              logger.fatal "[FAILED] #{version_fullname} release to #{git_status[:uri]} failed!\n"
            else
              release_result_output(version_release, true, {:release_path => git_status[:uri], :log_path => log_path})
              logger.fatal "[SUCCESSED] #{version_fullname} release to #{git_status[:uri]} successed!\n"
            end
          else
            fail_msg.each {|msg| logger.info(msg)}
            release_result_output(version_release, false, {:release_path => release_path, :log_path => log_path})
            logger.fatal "[FAILED] #{version_fullname} release to #{release_path} failed!\n"
          end
        else
          logger.info("Get repo by version_id[#{version_id}], #{release_path}")
          git_status = write_spec_to_git(r, logger, version_release.id)
          if git_status[:status] == 0
            release_result_output(version_release, false, {:release_path => git_status[:uri], :log_path => log_path})
            logger.fatal "[FAILED] #{version_fullname} release to #{git_status[:uri]} failed!\n"
          else
            release_result_output(version_release, true, {:release_path => git_status[:uri], :log_path => log_path})
            logger.fatal "[SUCCESSED] #{version_fullname} release to #{git_status[:uri]} successed!\n"
          end
        end
      rescue => e
        logger.error e.message
        release_result_output(version_release, false, {:release_path => git_status[:uri], :log_path => log_path})
        logger.fatal "[FAILED] #{version_fullname} release to #{git_status[:uri]} failed!\n"
      end
    end
  end


  #-------------------------------------------------------

  #------------------ Old Release Way ------------------

  def old_release(release)
    version = release.version
    project = release.project
    log_folder = release.log_folder

    # Find all release_pathes here and return if there is no release_pathes
    release_pathes = release.old_release_pathes
    return if release_pathes.empty?

    # Create log folder
    FileUtils.mkdir_p(log_folder) unless Dir.exist?(log_folder)

    begin
      # Connect to FTP server
      smber = Api::Smb.new

      # Download Zip File
      file = File.join("Applications", project.identifier, "#{version.fullname}.zip")
      smber_status = smber.download file
      smber.close

      raise "Cannot find the apk in server: #{file}" unless smber_status.success?
    rescue => e
      # output release result: release failed
      release_pathes.each do |release_path|
        r_path = release_path.release_path

        log_path = log_folder.join("#{Digest::MD5.hexdigest r_path}.log").to_s
        logger = logger_new log_path, release
        logger.info "Apk download path: #{version.path || file}"
        logger.error e.message
        logger.error "Error, download apk failed"

        release_result_output(release, false, :release_path => r_path, :log_path => log_path)
        logger.error "[FAILED] #{version.fullname} release to #{r_path} failed!\n"
      end
      return false
    end

    # Extract Zip file
    dest_path = smber.dest file
    dest_extracted_path = File.join(File.dirname(dest_path), version.fullname)
    Zip::File.open dest_path do |zip_file|
      zip_file.each do |f|
        f_path = File.join(dest_extracted_path, f.name)
        FileUtils.mkdir_p(File.dirname(f_path))
        zip_file.extract(f, f_path) unless File.exist?(f_path)
      end
    end

    # Check if Svn or Git
    release_pathes.each do |release_path|
      r_path = release_path.release_path
      next if r_path.empty?
      r_way = release_path.release_ways.split(',').sort.last.to_i
      log_path = log_folder.join("#{Digest::MD5.hexdigest r_path}.log").to_s
      options = {:release_path => r_path, :release_way => r_way, :apk_path => dest_extracted_path, :log_path => log_path}
      r_path.match(/\Assh/) ? old_git_release(release, options) : old_svn_release(release, options)
    end
  end

  #-------------------------------------------------------


  def old_git_release(release, options = {})
    apk_path = options[:apk_path]
    release_path = options[:release_path]
    release_way = options[:release_way]
    log_path = options[:log_path]
    version_fullname = release.version.fullname

    # Set log path
    logger = logger_new log_path, release

    # Git Clone Repository
    git = Api::Release::Git.new(:repo => release_path, :release_way => release_way, :logger => logger)
    git.clone

    # Copy Files to target dir
    git.copyfiles apk_path

    # Git Commit and Push
    git.commit "Release: #{version_fullname}"

    # Export result
    release_result_output(release, true, options)
    logger.fatal "[SUCCESSED] #{version_fullname} release to #{release_path} successed!\n"
  rescue => e
    logger.error e.message
    release_result_output(release, false, options)
    logger.fatal "[FAILED] #{version_fullname} release to #{release_path} failed!\n"
  end

  def old_svn_release(release, options = {})
    apk_path = options[:apk_path]
    release_path = options[:release_path]
    release_way = options[:release_way]
    log_path = options[:log_path]
    version_fullname = release.version.fullname

    # Set log path
    logger = logger_new log_path, release

    # Svn Clone Repository
    svn = Api::Release::Svn.new(:repo => release_path, :release_way => release_way, :logger => logger)
    unless svn.ls
      ppath = release_path.split("/").to(-2).join("/")
      if svn.ls ppath # Check if parent folder exsit
        svn.mkdir release_path, "Add Folder: #{release_path.split("/").last}"
      else
        raise "Release Path Error"
      end
    end
    svn.clone
    svn.copyfiles apk_path
    svn.delete
    svn.add
    svn.commit "Release: #{version_fullname}"
    release_result_output(release, true, options)
    logger.fatal "[SUCCESSED] #{version_fullname} release to #{release_path} successed!\n"
  rescue => e
    logger.error e.message
    release_result_output(release, false, options)
    logger.fatal "[FAILED] #{version_fullname} release to #{release_path} failed!\n"
  end

  def logger_new(log_path, release)
    Logger.new(log_path).tap do |logger|
      logger.formatter = -> (severity, datetime, progname, msg) { "[#{datetime.to_s(:db)}] #{msg}\n" }
      logger.info "#{('-'*20)} RELEASE STARTING #{('-'*20)}"
      logger.info "Author: #{release.author.name} (id = #{release.author_id})"
    end
  end

  def release_result_output(release, status, options = {})
    release_path = options[:release_path]
    status = status ? 1 : 0
    log_md5 = options[:log_path].split("/").last.split(".log").first
    release_record = {uri: release_path, status: status, log: log_md5}

    result = release.result
    if exsit_item = result.detect { |r| r[:uri] == release_path }
      result.map! { |r| r == exsit_item ? release_record : r }
    else
      result.push release_record
    end
    release.update_column :result, result
  end

  def send_released_notification(release)
    default_cc = Setting.notified_version_released.select { |mail| mail.include?('@') }
    default_cc_two = Setting.notified_production_version_compiled.map { |role_id| release.project.users_of_role(role_id) }.flatten
    cc = User.where(:id => release.mail_receivers)
    receivers = [release.author] | cc | [default_cc] | default_cc_two
    begin
      Mailer.version_released_notification(receivers, :release => release).deliver
    rescue
      receivers.each do |receiver|
        begin
          Mailer.version_released_notification(receiver, :release => release).deliver
        rescue
          next
        end
      end
    end
  end

  #-------------------------------------------------------

  private
  # write spec.yml to git
  def write_spec_to_git(repo, logger, version_release_id)
    # git clone or fetch
    repo_url = repo['repo_url'] # ssh://gerritroot@19.9.0.152:29418/android_mtk_m_6755_c66_mp/master
    git_repo = GitHelper.parse_url(repo_url)

    repo_branch = git_repo[:repo_branch]
    project_spec_name = repo['project_spec_name'] # 02_B
    project_name = repo['project_name'] # GBL7553A
    spec_file_dir = project_name[0 .. 6] # GBL7553
    spec_file_name = "#{project_name.to_s.include?('_TASTE') ? project_name[0..7] : project_name}#{project_spec_name}.yml" # GBL7553A02_B.yml
    git_repo[:repo_uri] = git_repo[:repo_uri].gsub('/gn_project', '') if project_name.to_s.start_with?('BJ') || repo_branch.eql?("vm4_gionee_local")

    if project_name.to_s.start_with?('BJ')
      uri = File.join(git_repo[:repo_uri], "config", spec_file_dir, spec_file_name) # ssh://USER@19.9.0.152:29418/android_mtk_m_6755_c66_mp/gn_project/config/GBL7553/GBL7553A02_B.yml
    elsif project_name.to_s.start_with?("SW17G15")
      git_repo[:repo_uri] = git_repo[:repo_uri].gsub('gn_project', 'SW17G15_gionee')
      git_repo[:repo_name] += "/SW17G15_gionee"
      repo_branch = "master"
      uri = File.join(git_repo[:repo_uri], "gn_project", spec_file_dir, spec_file_name) # ssh://USER@19.9.0.152:29418/android_qc_n_qrd8920_cs/SW17G15_gionee/gn_project/SW17G15/SW17G15A01_A.yml
    else
      uri = File.join(git_repo[:repo_uri], spec_file_dir, spec_file_name) # ssh://USER@19.9.0.152:29418/android_mtk_m_6755_c66_mp/gn_project/GBL7553/GBL7553A02_B.yml
    end

    # ssh://gerritroot@19.9.0.151:29418/android_qc_n_qrd8920_cs/branch_sw17g15_master
    if repo_url.to_s.end_with?("android_qc_n_qrd8920_cs/branch_sw17g15_master") || repo_url.to_s.end_with?("android_qc_n_qrd8920_cs/branch_sw17g15_gionee_master") ||
        repo_url.to_s.end_with?("android_mtk_n_6739_mp/branch_sw17g18_gionee_master") || repo_url.to_s.end_with?("android_mtk_n_6739_mp/branch_sw17g18_master")
      if repo_url.to_s.end_with?("branch_sw17g15_gionee_master")
        git_repo[:repo_uri] = git_repo[:repo_uri].gsub('gn_project', 'SW17G15_gionee')
        git_repo[:repo_name] += "/SW17G15_gionee"
      elsif repo_url.to_s.end_with?("branch_sw17g15_master")
        git_repo[:repo_uri] = git_repo[:repo_uri].gsub('gn_project', 'SW17G15')
        git_repo[:repo_name] += "/SW17G15"
      elsif repo_url.to_s.end_with?("branch_sw17g18_gionee_master")
        git_repo[:repo_uri] = git_repo[:repo_uri].gsub('gn_project', 'SW17G18_gionee')
        git_repo[:repo_name] += "/SW17G18_gionee"
      elsif repo_url.to_s.end_with?("branch_sw17g18_master")
        git_repo[:repo_uri] = git_repo[:repo_uri].gsub('gn_project', 'SW17G18')
        git_repo[:repo_name] += "/SW17G18"
      end
      uri = File.join(git_repo[:repo_uri], "gn_project", spec_file_dir, spec_file_name) # ssh://auto_rom_release@19.9.0.151:29418/android_qc_n_qrd8920_cs/SW17G15/gn_project/SW17G17/SW17G17Z50_A.yml
      repo_branch = "master"
    end

    if repo_branch.eql?("vm4_gionee_local")
      uri = File.join(git_repo[:repo_uri], "mt6763o/gn_project", spec_file_dir, spec_file_name)
    end

    status = 1
    begin
      git = GitHelper.clone(git_repo[:repo_uri], git_repo[:repo_name], repo_branch)
      GitHelper.clear(git, repo_branch)
      GitHelper.pull_rebase(git, repo_branch)
    rescue => e
      logger.error("Git option failed, #{e}")
      status = 0
    end
    logger.info("Working dir #{git.dir.to_s}")

    # write spec.yml
    project_spec_id = repo['project_spec_id']
    production_name = repo['production_name'] # Amigo_GameHall
    production_spec_name = repo['production_spec_name'] # 01
    production_version_id = repo['production_version_id']
    production_version_name = repo['production_version_name'] # V1.0.0.a
    production_full_version = "#{production_spec_name}_#{production_version_name}" # 01_V1.0.0.a

    if project_name.to_s.start_with?('BJ')
      spec_file = File.join(git.dir.to_s, "config", spec_file_dir, spec_file_name) # android_mtk_m_6755_c66_mp/master/GBL7553/GBL7553A02_B.yml
    elsif project_name.to_s.start_with?("SW17G15")
      spec_file = File.join(git.dir.to_s, "gn_project", spec_file_dir, spec_file_name) # android_mtk_m_6755_c66_mp/master/gn_project/GBL7553/GBL7553A02_B.yml
    else
      spec_file = File.join(git.dir.to_s, spec_file_dir, spec_file_name) # android_mtk_m_6755_c66_mp/master/GBL7553/GBL7553A02_B.yml
    end

    if repo_url.to_s.end_with?("android_qc_n_qrd8920_cs/branch_sw17g15_master") || repo_url.to_s.end_with?("android_qc_n_qrd8920_cs/branch_sw17g15_gionee_master") ||
        repo_url.to_s.end_with?("android_mtk_n_6739_mp/branch_sw17g18_gionee_master") || repo_url.to_s.end_with?("android_mtk_n_6739_mp/branch_sw17g18_master")
      spec_file = File.join(git.dir.to_s, 'gn_project', spec_file_dir, spec_file_name)
    end

    if repo_branch.eql?("vm4_gionee_local")
      spec_file = File.join(git.dir.to_s, 'mt6763o/gn_project', spec_file_dir, spec_file_name)
    end

    md5_old = Digest::MD5.file(spec_file).hexdigest if File.exist?(spec_file)
    logger.info("Start write apps to #{spec_file}")
    msg = write_spec_yml(spec_file, project_spec_id, production_version_id, production_name, production_full_version)
    logger.info("End write apps to #{spec_file}")
    md5_new = Digest::MD5.file(spec_file).hexdigest

    # git push
    if project_name.to_s.start_with?('BJ')
      spec_file_git_path = File.join("config", spec_file_dir, spec_file_name) # GBL7553/GBL7553A02_B.yml
    elsif project_name.to_s.start_with?("SW17G15")
      spec_file_git_path = File.join("gn_project", spec_file_dir, spec_file_name) # gn_project/GBL7553/GBL7553A02_B.yml
    else
      spec_file_git_path = File.join(spec_file_dir, spec_file_name) # GBL7553/GBL7553A02_B.yml
    end

    if repo_url.to_s.end_with?("android_qc_n_qrd8920_cs/branch_sw17g15_master") || repo_url.to_s.end_with?("android_qc_n_qrd8920_cs/branch_sw17g15_gionee_master") ||
        repo_url.to_s.end_with?("android_mtk_n_6739_mp/branch_sw17g18_gionee_master") || repo_url.to_s.end_with?("android_mtk_n_6739_mp/branch_sw17g18_master")
      spec_file_git_path = File.join('gn_project', spec_file_dir, spec_file_name)
    end

    if repo_branch.eql?("vm4_gionee_local")
      spec_file_git_path = File.join('mt6763o/gn_project', spec_file_dir, spec_file_name)
    end

    gst = git.status[spec_file_git_path]
    logger.info("Git status: #{gst.type} #{gst.path}, md5[#{md5_old} -> #{md5_new}]") if gst != nil

    if md5_new != md5_old # changed gst != nil and gst.type != nil and
      for i in 0..3 # retry 3 times when meet exception
        begin
          sleep(i * 3)
          logger.info("Updating spec.yml NO:#{i}: #{gst.type} #{gst.path}") # M GBL7553/GBL7553A02_B.yml
          git.add(spec_file)
          logger.info("Git add files '#{spec_file}' to #{git.dir.to_s}")
          git.commit("#{msg} to #{spec_file_name}(#{version_release_id})")
          logger.info("Git commit #{msg} to #{spec_file_name}")
          GitHelper.pull_rebase(git, repo_branch)
          logger.info("Git fetch and rebase from #{repo_branch}")
          git.push('origin', repo_branch)
          logger.info("Git push to #{repo_branch}")
          status = 1
          break
        rescue => e
          logger.error("Updating spec.yml NO:#{i} failed, #{e}")
          status = 0
        end
      end
    end
    {:uri => uri, :status => status, :msg => msg}
  end

  def write_spec_yml(spec_file, project_spec_id, production_version_id, production_name, production_full_version)
    production_full_name = "#{production_name}_#{production_full_version}" # Amigo_GameHall_01_V1.0.0.a
    production_hash = {'v' => production_full_version, 'vid' => production_version_id}

    production_type = Version.find(production_version_id).project.production_type
    spec_production_type = spec_production_type(production_type)
    spec = {'spec' => {'id' => project_spec_id}, spec_production_type => {production_name => production_hash}}

    if not File.exist?(spec_file)
      logger.info("Adding #{spec_file}")
      spec_dir = File.dirname(spec_file)
      if not File.exist?(spec_dir)
        FileUtils.mkdir_p(spec_dir)
        logger.info("Created #{spec_file}")
      end
      # spec['apps'].merge!(YAML.load(necessary_apks_by_project_spec_id(project_spec_id))) # load apks from project_spec_id
      msg = "Adding #{production_full_name}"
    else
      spec = YAML.load_file(spec_file)
      logger.info("Updating #{spec_file}")
      spec_production = spec[spec_production_type][production_name] if spec[spec_production_type]
      old = "#{production_name}_#{spec_production ? spec_production['v'] : 'nil'}"
      # spec['apps'][production_name] = production_hash
      msg = "Updating #{old} -> #{production_full_name}"

      spec = delete_apk_from_spec_yml(spec_file, project_spec_id, production_type)

      spec[spec_production_type] ||= {}
      spec[spec_production_type][production_name] ||= {}
      spec[spec_production_type][production_name]['v'] = production_full_version
      spec[spec_production_type][production_name]['vid'] = production_version_id
    end
    # spec['apps'].merge!(YAML.load(necessary_apks_by_project_spec_id(project_spec_id))) # load apks from project_spec_id

    logger.info("#{msg} to #{spec_file}")
    File.open(spec_file, 'w') do |file|
      file.write(YAML.dump(spec)) # TODO: sort apps
    end
    msg
  rescue => e
    logger.error("Write spec.yml failed, #{e}")
  end

  # result: {
  #   'uri' => 'ssh://gerritroot@19.9.0.152:29418/android_mtk_m_6755_c66_mp/gn_project/GBL7553/GBL7553A02_B.yml',
  #   'status' => 1
  # }
  # def self.write_release_result(version_release, result)
  #   logger.info("Writing release result[#{result}], #{version_release.to_json}")
  #   version_release.update_columns(:result => result)
  #   send_released_notification(version_release)
  # end

  # spec = YAML.load_file('/data/amige/repo/gn_project/android_mtk_m_6755_c66_mp/master/GBL7553/GBL7553A02_B.yml')
  # spec['apps'].merge!(YAML.load(VersionReleaseJob.send(:necessary_apk)))
  def necessary_apks_by_project_spec_id(spec_id)
    SpecVersion.app_list_with_successful_version(spec_id).map { |app|
      ver = Version.find(app.version_id)
      history_version_id = history_success_version(spec_id, app.production_id || Version.find(app.version_id).project_id).first
      history_version = Version.find(history_version_id) unless history_version_id.nil?
      app_min_version = Version.success_child_version(app.production_id, app.version_id).blank? ? nil : Version.success_child_version(app.production_id, app.version_id).first
      app_version = app_min_version || history_version || ver

      %[
      #{Production.find(app.production_id).name}:
        v: #{app_version.spec.name.to_s + "_" + app_version.name.to_s}
        vid: #{app_version.id}
      ] if app_version
    }.join("")
  end

  def history_success_version(spec_id, app_id)
    records = Spec.find(spec_id).spec_alter_records.where("prop_key = 'app_version_id' and app_id = #{app_id}").reorder("updated_at desc")

    records.blank? ? [nil] : records.map { |ver| ver.value unless Version.released_version(ver.value).blank? }.uniq
  end

  def delete_apk_from_spec_yml(spec_file, spec_id, production_type)
    spec = YAML.load_file(spec_file)
    spec_apks = YAML.load(necessary_apks_by_project_spec_id(spec_id))
    spec_production_type = spec_production_type(production_type)

    spec[spec_production_type].each do |app|
      if spec_apks[app[0].to_s].nil?
        # Delete apk from yml
        spec[spec_production_type].delete(app[0])
      end
    end if spec[spec_production_type]
    spec
  end

  def spec_production_type(type)
    case type.to_i
      when Project::PROJECT_PRODUCTION_TYPE[:resource] then
        'res'
      when Project::PROJECT_PRODUCTION_TYPE[:jar] then
        'sdk'
      else
        'apps'
    end
  end

end
