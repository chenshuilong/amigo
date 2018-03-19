class SignFileMergeJob < ActiveJob::Base
  queue_as :default

  # rescue_from(ErrorLoadingSite) do
  #   retry_job wait: 1.minutes, queue: :low_priority
  # end

  def perform(attachment_id)
    atta = Attachment.find_by(:id => attachment_id)
    logger.info(atta.to_json) # atta info

    files = Dir.glob(atta.diskfile(atta.uniq_key + '*'))
    return true if atta.blank? || files.blank? || atta.container_id.blank?
    #num = Attachment.where("container_type = 'Issue' AND container_id = #{atta.container_id} AND filesize > 52428800 AND id < #{attachment_id}").count
    filename = "#{atta.filename}"

    # Create folder
    path = File.join(Attachment::IPS["2"][:path], '')
    FileUtils.mkdir_p(path) unless File.directory?(path)

    begin
      # Merge file
      File.open(File.join(path, filename), 'wb') do |outfile|
        files.sort_by{|f| f.split("/").last.split(".")[1].to_i}.each do |file|
          outfile.write(File.open(file, 'rb').read)
        end
      end

      # Update Attachment And Container infos And send Jenkins
      atta.update_columns(:disk_filename => filename, :disk_directory => "", :ftp_ip => 2)
      atta.container.update_columns(:status => 2)
      atta.container.do_jenkins_job
      
      # # Delete .qp file
      FileUtils.rm_rf(files)

    rescue => e
      logger.fatal('Error ocurred when merging files!')
      logger.fatal e
    end
  end
end