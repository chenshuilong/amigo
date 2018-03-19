class FileMergerJob < ActiveJob::Base
  queue_as :default

  # rescue_from(ErrorLoadingSite) do
  #   retry_job wait: 1.minutes, queue: :low_priority
  # end

  def perform(attachment_id)
    atta = Attachment.find_by(:id => attachment_id)
    logger.info(atta.to_json) # atta info

    files = Dir.glob(atta.diskfile(atta.uniq_key + '*'))
    return true if atta.blank? || files.blank? || atta.container_id.blank?

    num = Attachment.where("container_type = 'Issue' AND container_id = #{atta.container_id} AND filesize > 52428800 AND id < #{attachment_id}").count
    filename = num == 0 ? "#{atta.container_id}.#{atta.file_ext}" : "#{atta.container_id}_#{num}.#{atta.file_ext}"

    # Create folder
    path = File.join(Attachment::IPS["1"][:path], atta.remote_target_directory.to_s)
    FileUtils.mkdir_p(path) unless File.directory?(path)

    begin
      # Merge file
      File.open(File.join(path, filename), 'wb') do |outfile|
        files.sort_by{|f| f.split("/").last.split(".")[1].to_i}.each do |file|
          outfile.write(File.open(file, 'rb').read)
        end
      end

      # Update Attachment
      atta.update_columns(:disk_filename => filename, :disk_directory => atta.remote_target_directory.to_s, :ftp_ip => 1)

      # # Delete .qp file
      FileUtils.rm_rf(files)

      # preload app version release attachment
      atta.preload_file

    rescue => e
      logger.fatal('Error ocurred when merging files!')
      logger.fatal e
    end
  end
end
