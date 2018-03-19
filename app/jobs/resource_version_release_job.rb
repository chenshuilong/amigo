class ResourceVersionReleaseJob < VersionReleaseJob
  queue_as :resource_release

  def perform(thirdparty_id)
    thirdparty = Thirdparty.find(thirdparty_id)

    release_thread = Thread.new { resource_release(thirdparty) }
    release_thread.join

    thirdparty.save
  end

  #------------------ Thirdparty Release Way ------------------

  def resource_release(thirdparty)
    repos = thirdparty.release_ids.blank? ? [] : Repo.get_thirdparty_version_release(thirdparty) # Repo.get_by_version_id(thirdparty.release_ids.join(','))
    repos.each do |r|
      release_path = r['repo_url']
      version_fullname = r['version_fullname']
      # Create log folder
      log_folder = thirdparty.log_folder
      FileUtils.mkdir_p(log_folder) unless Dir.exist?(log_folder)
      log_path = log_folder.join("#{Digest::MD5.hexdigest release_path}.log").to_s
      logger = logger_new log_path, thirdparty
      begin
        git_status = write_spec_to_git(r, logger, thirdparty.id)
        if git_status[:status] == 0
          thirdparty.status = 7
          release_result_output(thirdparty, false, {:release_path => git_status[:uri], :log_path => log_path})
          logger.fatal "[FAILED] #{version_fullname} release to #{git_status[:uri]} failed!\n"
        else
          thirdparty.status = 5
          release_result_output(thirdparty, true, {:release_path => git_status[:uri], :log_path => log_path})
          logger.fatal "[SUCCESSED] #{version_fullname} release to #{git_status[:uri]} successed!\n"
        end
      rescue => e
        logger.error e.message
        thirdparty.status = 7
        release_result_output(thirdparty, false, {:release_path => git_status[:uri], :log_path => log_path})
        logger.fatal "[FAILED] #{version_fullname} release to #{git_status[:uri]} failed!\n"
      end
    end
  end

  #-------------------------------------------------------

end
