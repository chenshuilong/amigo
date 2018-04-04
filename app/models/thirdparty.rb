class Thirdparty < ActiveRecord::Base

  serialize :version_ids
  serialize :release_ids
  serialize :result, Array

  belongs_to :spec
  belongs_to :author, :class_name => 'User'

  acts_as_attachable :view_permission => true,
                     :edit_permission => true,
                     :delete_permission => true

  # after_create :check_fileinfo

  THIRDPARTY_PATH    = "#{Rails.root}/files/thirdparty"
  THIRDPARTY_32LABEL = ['armeabi-v7a', 'armeabi']
  THIRDPARTY_64LABEL = ['arm64-v8a']
  THIRDPARTY_PRIVILEGED_MODULE = ['BalanceAnalytics', 'IndusCoreSettings', 'IndusCoreServices', 'MinusOne', 'IndusEssentials']

  Thirdparty_STATUS = {:submitted => 1, :releasing => 3, :completed => 5, :failed => 7}
  Thirdparty_CATEGORY = {:preload => 1, :resource => 2}

  default_scope { order(created_at: :desc) }

  validates :spec_id, presence: true
  validates :category, inclusion: {in: Thirdparty_CATEGORY.values}

  scope :preload_apps, -> { where(:category => Thirdparty_CATEGORY[:preload]) }
  scope :resource_apps, -> { where(:category => Thirdparty_CATEGORY[:resource]) }

  def preload?
    self.category == Thirdparty_CATEGORY[:preload]
  end

  def resource?
    self.category == Thirdparty_CATEGORY[:resource]
  end

  def extract_zip_file
    FileUtils.mkdir_p(File.dirname(extract_path)) unless Dir.exist?(extract_path)

    cmd = Api::ThirdpartyRelease::StudioCommand.new

    # Clear directory before extract zip file
    cmd.exec_command("rm -rf #{extract_path}")

    attachments.each { |attachment|
      cmd.exec_command("unzip #{attachment.diskfile} -d #{extract_path}") if File.exist?(attachment.diskfile)
    }
  end

  def apk_files
    Api::ThirdpartyRelease::FileHelper.new.diretory_files(extract_path, ".apk")
  end

  def zip_files
    Api::ThirdpartyRelease::FileHelper.new.diretory_files(extract_path, ".zip")
  end

  def extract_path
    File.join(THIRDPARTY_PATH, spec_name, created_at.strftime('%Y%m%d%H%M%S'))
  end

  def status_name
    l("thirdparty_version_release_status_#{Thirdparty_STATUS.detect { |k, v| v == self.status }.first.to_s}".to_sym)
  end

  def spec_name
    spec.name
  end

  def version_name
    "V#{created_at.strftime('%Y%m%d')}"
  end

  def version_fullname
    "V#{created_at.strftime('%Y%m%d%H%M%S')}"
  end

  def project
    spec.project
  end

  def production_name(cn_name)
    Production.find_by_identifier(cn_name)
  end

  def list_so_files(cmd, apk_file)
    res = cmd.exec_command("zipinfo -1 #{apk_file} | grep -w ^lib")
    res[3].read.blank? ? res[2].readlines : []
  end

  def write_mk_file(mk_file, mk_text)
    File.open(mk_file, 'w') do |file|
      file.write("") # Clean text before wirte content to file
      file.write(mk_text)
    end
  end

  def upload_zip_to_server
    zip_files.uniq.each do |zip_file|
      file_path = zip_file.to_s.split('/')
      product = production_name(file_path[-2])

      begin
        # Upload zip file to ftp server
        smber = Api::Smb.new
        smber.cd("Applications")
        smber.mkdir("#{product.identifier}") unless smber.cd("#{product.identifier}").success?
        smber.cd("#{product.identifier}")
        smber.put(zip_file, "#{file_path[-1]}")
        smber.close
      rescue => e
        errors.add(:name, e.to_s)
      end
    end
  end

  def resource_package_upload_sever
    begin
      # Generate version for resource package
      zip_file = self.attachments.last.diskfile
      project = self.spec.project
      ver = project.versions.find_by_name_and_spec_id(version_fullname, self.spec_id)
      project.versions << Version.new({:name => version_fullname,
                                       :spec_id => self.spec_id,
                                       :description => "Resource package version",
                                       :compile_status => 6,
                                       :status => 1,
                                       :unit_test => 0,
                                       :priority => 3,
                                       :repo_one_id => 3,
                                       :sharing => 'none'}) if ver.blank?
      ver ||= project.versions.find_by_name_and_spec_id(version_fullname, self.spec_id)
      self.update_columns(:version_ids => [ver.id])

      # Upload zip file to ftp server
      smber = Api::Smb.new
      smber.cd("Applications")
      smber.mkdir("#{project.identifier}") unless smber.cd("#{project.identifier}").success?
      smber.cd("#{project.identifier}")
      smber.put(zip_file, "#{ver.fullname}.zip")
      smber.close
    rescue => e
      errors.add(:name, e.to_s)
    end
  end

  def make_android_mk_to_zip
    version_ids = []
    # Generate android.mk for apk
    cmd = Api::ThirdpartyRelease::StudioCommand.new

    apk_files.uniq.each do |apk_file|
      begin
        ver_name = version_name
        file_path = apk_file.to_s.split('/')
        product = production_name(file_path[-2])
        mk_file = "#{file_path[0..-2].join('/')}/Android.mk"

        unless THIRDPARTY_PRIVILEGED_MODULE.include?(product.identifier)
          mk_text = android_mk_content(product.identifier)
          mk_text.pop if self.release_type.to_i == 2

          # List all so files in a apk
          so_files = list_so_files(cmd, apk_file)
          unless so_files.blank?
            # Check 32bit or 64bit
            so_files = so_files.map { |so| so.to_s.split('/')[1] }
            if (THIRDPARTY_32LABEL.first.in?(so_files) || THIRDPARTY_32LABEL.last.in?(so_files)) && THIRDPARTY_64LABEL.first.in?(so_files)
              mk_text.insert(-1, 'LOCAL_MULTILIB := both')
            elsif (THIRDPARTY_32LABEL.in?(so_files) || THIRDPARTY_32LABEL.last.in?(so_files)) && !THIRDPARTY_64LABEL.first.in?(so_files)
              mk_text.insert(-1, 'LOCAL_MULTILIB := 32')
            elsif !(THIRDPARTY_32LABEL.in?(so_files) || THIRDPARTY_32LABEL.last.in?(so_files)) && THIRDPARTY_64LABEL.first.in?(so_files)
              mk_text.insert(-1, 'LOCAL_MULTILIB := 64')
            end
          end

          mk_text.insert(-1, 'PRODUCT_COPY_FILES += $(LOCAL_PATH)/' + product.config_info.to_s + ':system/etc/' + product.config_info.to_s) unless product.config_info.blank?
          mk_text.insert(-1, 'include $(BUILD_PREBUILT)', 'endif')

          # Write content to Android.mk
          write_mk_file(mk_file, mk_text.join("\r\n"))
        end

        # Rename apk file
        File.rename(apk_file, "#{file_path[0..-2].join('/')}/#{product.identifier}#{File.extname(apk_file)}")

        # Generate version for production
        project_version = product.versions.find_by_name(ver_name)
        project_spec = product.specs.find_by_name(self.spec_name)
        product.versions << Version.new({:name => ver_name,
                                         :spec_id => project_spec.id,
                                         :description => "Thirdparty version",
                                         :compile_status => 6,
                                         :status => 1,
                                         :unit_test => 0,
                                         :priority => 3,
                                         :repo_one_id => 3,
                                         :sharing => 'none'
                                        }) if project_version.blank? && project_spec.present?

        if project_version.present?
          version_ids << project_version.id unless version_ids.include?(project_version.id)
        else
          version_ids << product.versions.find_by_name(ver_name).id unless version_ids.include?(product.versions.find_by_name(ver_name).id)
        end

        # Package zip
        zip_file = "#{file_path[0..-2].join('/')}/#{product.identifier}_#{self.spec_name}_#{ver_name}.zip"
        cmd.exec_command("zip -j #{zip_file} #{file_path[0..-2].join('/')}/*")
      rescue => e
        next
      end
    end

    self.update_columns(:version_ids => version_ids)
  end

  def android_mk_content(apk_name)
    module_path = apk_name == "3rd_BaiDuInput" ? '$(GN_SYSTEM_VENDOR_ROM_APPS)' : '$(GN_OUT_DATA_VENDOR_APPS)'
    [
        'ifeq ("$(GN_APK_' + apk_name.to_s.upcase + '_SUPPORT)","yes")',
        'LOCAL_PATH := $(call my-dir)',
        'include $(CLEAR_VARS)',
        'LOCAL_MODULE_TAGS := optional',
        'LOCAL_MODULE := ' + apk_name.to_s,
        'LOCAL_SRC_FILES := $(LOCAL_MODULE).apk',
        'LOCAL_MODULE_CLASS := APPS',
        'LOCAL_CERTIFICATE := PRESIGNED',
        'LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)',
        'LOCAL_MODULE_PATH := $(GN_OUT_DATA_VENDOR_APPS)'
    ]
  end

  def log_folder
    time = created_at || DateTime.now
    # Rails.root.join('files', "#{time.strftime("%Y/%m")}/release_log/#{id}")
    Attachment::ROOT_DIR.join('files', "#{time.strftime("%Y/%m")}/thirdparty_release_log/#{id}")
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

  def check_fileinfo
    atta = self.attachments.last
    if atta.present? && atta.ftp_ip.blank? && /.zip\Z/ === atta.disk_filename && atta.filesize.to_i < 52428800
      self.upload_zip_to_server
    end
  end

end
