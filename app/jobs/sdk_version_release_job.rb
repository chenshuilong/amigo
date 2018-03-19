class SdkVersionReleaseJob < VersionReleaseJob
  queue_as :sdk_release

  def perform(sdk_id)
    sdk = VersionReleaseSdk.find(sdk_id)

    # 系统型--发布时需要将版本更新到yml
    # 应用型--发布时只需传到Maven库

    if sdk.is_system?
      yml_release_thread = Thread.new { sdk_yml_release(sdk) }
      yml_release_thread.join
    end

    if sdk.is_app?
      mvn_release_thread = Thread.new { sdk_maven_release(sdk) }
      mvn_release_thread.join
    end

    sdk.save
  end

  #------------------ SDK Yml Release Way ------------------

  def sdk_yml_release(sdk)
    release_project_ids = []
    repos = Repo.get_by_version_id(sdk.version_id)

    repos.each do |r|
      release_project_ids << r['project_id'].to_i unless release_project_ids.include?(r['project_id'].to_i)
      release_path = r['repo_url']
      version_fullname = r['version_fullname']
      # Create log folder
      log_folder = sdk.log_folder
      FileUtils.mkdir_p(log_folder) unless Dir.exist?(log_folder)
      log_path = log_folder.join("#{Digest::MD5.hexdigest release_path}.log").to_s
      logger = logger_new log_path, sdk
      begin
        git_status = write_spec_to_git(r, logger, sdk.id)
        if git_status[:status] == 0
          sdk.status = 7
          release_result_output(sdk, false, {:release_path => git_status[:uri], :log_path => log_path})
          logger.fatal "[FAILED] #{version_fullname} release to #{git_status[:uri]} failed!\n"
        else
          sdk.status = 5
          release_result_output(sdk, true, {:release_path => git_status[:uri], :log_path => log_path})
          logger.fatal "[SUCCESSED] #{version_fullname} release to #{git_status[:uri]} successed!\n"
        end
      rescue => e
        logger.error e.message
        sdk.status = 7
        release_result_output(sdk, false, {:release_path => git_status[:uri], :log_path => log_path})
        logger.fatal "[FAILED] #{version_fullname} release to #{git_status[:uri]} failed!\n"
      end
    end

    sdk.release_project_ids = release_project_ids.uniq
  end

  #-------------------------------------------------------

  #------------------ SDK Maven Release Way ------------------

  def sdk_maven_release(sdk)
    begin
      # Download zip from ftp then upzip
      sdk.download_zip
      sdk.extract_zip_file
      
      raise "没有生成对应的版本zip包" if sdk.version_path.blank?
      raise "未设置#{sdk.version.project.identifier}包名，请前往设置" if sdk.maven_package_name.blank?
      raise "#{sdk.version.project.identifier}包名无效" if !sdk.maven_package_name.to_s.start_with?('gionee.') || sdk.maven_package_name.to_s.split('.').length < 2

      # check sdk file type
      if sdk.maven_files.blank?
        raise "没有可发布的sdk文件"
      else
        if sdk.maven_files.size > 2
          raise "生成的版本zip包中文件异常jar类型文件不允许多个"
        elsif sdk.maven_files.size == 2
          if sdk.maven_files.find{|file| file.to_s.include?('class.')}
            mvn_file = sdk.maven_files.find{|file| !file.to_s.include?('class.')}
            raise "生成的版本zip包中文件异常jar类型文件不允许多个" if mvn_file.blank?
          else
            raise "生成的版本zip包中文件异常jar类型文件不允许多个"
          end
        else
          mvn_file = sdk.maven_files.first
        end
      end

      cmd = Api::ThirdpartyRelease::StudioCommand.new
      mvn_cmd = ["mvn deploy:deploy-file"]
      mvn_cmd << "-DgroupId=#{sdk.maven_package_name}"
      mvn_cmd << "-DartifactId=#{sdk.maven_artifact_id}"
      mvn_cmd << "-Dversion=#{sdk.maven_version}"
      mvn_cmd << "-Dpackaging=#{File.extname(mvn_file).delete('.')}"
      mvn_cmd << "-Dfile=#{mvn_file}"
      mvn_cmd << "-Durl=#{VersionReleaseSdk::MAVEN_DEPLOY_RUL}"
      mvn_cmd << "-DrepositoryId=#{sdk.maven_repository_id}"
      cmd.exec_command(mvn_cmd.join(' '))

      # Update maven result
      sdk.maven_result = {:success => 1, :message => "#{VersionReleaseSdk::MAVEN_DEPLOY_RUL}"}
      sdk.status = 5

      # Clear the temp dir
      cmd.exec_command("rm -rf #{sdk.temp_dir}")

    rescue => e
      logger.error e.message
      sdk.maven_result = {:success => 0, :message => "#{e.to_s}"}
      sdk.status = 7
    end
  end

  #-------------------------------------------------------

end
