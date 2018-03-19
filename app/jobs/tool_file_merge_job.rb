class ToolFileMergeJob < ActiveJob::Base
  queue_as :default

  # rescue_from(ErrorLoadingSite) do
  #   retry_job wait: 1.minutes, queue: :low_priority
  # end

  def perform(attachment_id)
    new_atta = Attachment.find_by(:id => attachment_id)
    tool = new_atta.container
    
    if new_atta.container_type == "Tool"
      ftp_ip = 3
      old_attas = tool.attachments.where(extra_type: new_atta.extra_type).where.not(id: new_atta.id)
      if old_attas.present?
        invalid_files = []
        old_attas.each do |atta|
          invalid_files << File.join(Attachment::IPS[ftp_ip.to_s][:path], "#{tool.id}/#{atta.id}")
        end
        FileUtils.rm_rf(invalid_files)
        old_attas.destroy_all
      end
      puts invalid_files
      puts new_atta.to_json # atta info
    elsif new_atta.container_type == "GoogleTool"
      ftp_ip = 4
    end

    files = Dir.glob(new_atta.diskfile(new_atta.uniq_key + '*'))
    return true if new_atta.blank? || files.blank? || new_atta.container_id.blank?
    filename = "#{new_atta.filename}"
    puts filename

    # Create folder
    path = File.join(Attachment::IPS[ftp_ip.to_s][:path], "#{tool.id}", "#{new_atta.id}")
    puts path
    FileUtils.mkdir_p(path) unless File.directory?(path)

    begin
      # Merge file
      File.open(File.join(path, filename), 'wb') do |outfile|
        files.sort_by{|f| f.split("/").last.split(".")[1].to_i}.each do |file|
          outfile.write(File.open(file, 'rb').read)
        end
      end

      # Update Attachment And Container infos And send Jenkins
      new_atta.update_columns(:disk_filename => filename, :disk_directory => path, :ftp_ip => ftp_ip)
      
      # # Delete .qp file
      FileUtils.rm_rf(files)

    rescue => e
      logger.fatal('Error ocurred when merging tool files!')
      logger.fatal e
    end
  end
end