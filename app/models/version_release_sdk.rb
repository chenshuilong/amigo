class VersionReleaseSdk < ActiveRecord::Base

  serialize :yml_result, Array
  serialize :maven_result, Hash
  serialize :release_project_ids, Array

  belongs_to :author, :class_name => 'User'
  belongs_to :version, :class_name => 'Version'

  validates :version_id, presence: true

  default_scope { order(created_at: :desc) }

  after_create :add_to_sdk_version_release_job

  MAVEN_DEPLOY_RUL = Rails.env.production? ? "http://ss.alm.gionee.com/nexus/content/repositories/android" : "http://192.168.188.165:8081/nexus/content/repositories/myrepo"
  SDK_TEMP_PATH = File.join(Rails.root, "files", "temp", "sdk")

  def status_name
    l("thirdparty_version_release_status_#{Thirdparty::Thirdparty_STATUS.detect { |k, v| v == self.status }.first.to_s}".to_sym)
  end

  def is_sdk?
    version.project.show_by(4) ? version.project.production_type.to_i == Production::PROJECT_PRODUCTION_TYPE[:jar].to_i : false
  end

  def is_app?
    is_sdk? ? version.project.sub_production_type.to_i == Project::PROJECT_SUB_PRODUCTION_TYPE[:app].to_i : false
  end

  def is_system?
    is_sdk? ? version.project.sub_production_type.to_i == Project::PROJECT_SUB_PRODUCTION_TYPE[:system] : false
  end

  def version_path
    self.version.path.to_s.gsub('\\18.8.8.2','').split('\\').join('/')
  end

  def maven_version
    self.version.name.to_s.gsub("V", "")
  end

  def maven_package_name
    self.version.project.package_name
  end

  def maven_repository_id
    Rails.env.production? ? "android" : "myrepo"
  end

  def maven_artifact_id
    self.version.fullname.to_s.gsub("_#{self.version.name.to_s}", '')
  end

  def maven_files
    jar_files | aar_files
  end

  def jar_files
    Api::ThirdpartyRelease::FileHelper.new.diretory_files(temp_dir, ".jar")
  end

  def aar_files
    Api::ThirdpartyRelease::FileHelper.new.diretory_files(temp_dir, ".aar")
  end

  def extract_zip_file
    FileUtils.mkdir_p(temp_dir) unless Dir.exist?(temp_dir)

    cmd = Api::ThirdpartyRelease::StudioCommand.new

    zip_file = File.join(Api::Smb::DEFAULT_DIR, "Applications", self.version.project.identifier, "#{self.version.fullname}.zip")
    cmd.exec_command("unzip #{zip_file} -d #{temp_dir}") if File.exist?(zip_file)
  end

  def temp_dir
    SDK_TEMP_PATH + "/#{self.id}"
  end

  def log_folder
    time = created_at || DateTime.now
    # Rails.root.join('files', "#{time.strftime("%Y/%m")}/release_log/#{id}")
    Attachment::ROOT_DIR.join('files', "#{time.strftime("%Y/%m")}/sdk_release_log/#{id}")
  end

  def parse_log(log_md5)
    path = log_folder.join("#{log_md5}.log")
    if File.exist? path
      content  = []
      item     = {}
      uniq_num = 1
      File.readlines(path).each do |line|
        if line.match /RELEASE\s+STARTING/ # Log start
          if item.present?
            content.push item
            item     = {}
            uniq_num = 1
          end
        elsif line.match /\A\[(\d+-\d+-\d+\s\d+:\d+:\d+)\]/ # Normal with datetime
          item["#{uniq_num} #{$1}"] = line.from(22)
          uniq_num += 1
        elsif line.present? && !line.match(/logger\.rb/)
          item[item.keys.last] = item.values.last + line
        else
          next
        end
      end
      content.push item
      content
    else
      l(:version_release_cannot_find_log)
    end
  end

  def download_zip
    begin
      smber = Api::Smb.new

      # Download Zip File
      file = File.join("Applications", self.version.project.identifier, "#{self.version.fullname}.zip")
      smber_status = smber.download file
      smber.close

      raise "Cannot find the apk in server: #{file}" unless smber_status.success?
    rescue => e
      return false
    end
  end

  def add_to_sdk_version_release_job
    if Rails.env.production?
      logger.info("add_to_version_release_job (id = #{self.id})")
      SdkVersionReleaseJob.perform_later(self.id)
    end
  end

end
