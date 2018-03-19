class VersionRelease < ActiveRecord::Base
  include AASM

  serialize :mail_receivers, Array
  serialize :result, Array
  serialize :note, Array # History
  serialize :additional_note, Hash

  acts_as_attachable :view_permission => :view_issues,
                     :edit_permission => :release_versions,
                     :delete_permission => :release_versions

  belongs_to :project
  belongs_to :author, :class_name => 'User'
  belongs_to :version, :class_name => 'Version'
  belongs_to :parent, :class_name => 'VersionRelease', :foreign_key => 'parent_id'
  has_many :children, -> (release){
    release.category == consts[:category][:complete] ? where("category = ?", consts[:category][:adapt]) : none
  }, :class_name => 'VersionRelease', :foreign_key => 'parent_id'

  before_create :add_project, :set_parent_id, :save_attachments_to_production_documents
  after_save :do_something_if_can

  validates :version_id, :tested_mobile, presence: true
  # validates :version_id, uniqueness: true
  validate  :check_ued_and_sqa_user_valid

  VERSION_RELEASE_STATUS = {
    :submitted => 1,
    :releasing => 3,
    :completed => 5,
    :rereleasing => 7,
    :refused => 9,
    :ued_accepted => 11,
    :ued_half_accepted => 13,
    :sqa_accepted => 21,
    :sqa_half_accepted => 23
  }
  VERSION_RELEASE_CATEGORY = {:complete => 1, :adapt => 2, :bugfix => 3}
  VERSION_RELEASE_TEST_TYPE = {:full_fuction => 1, :basic_function => 2}
  VERSION_RELEASE_BVT_TEST = {:passed => 1, :failed => 2}
  VERSION_RELEASE_FLUENCY_TEST = {:no_need => 1, :passed => 2, :failed => 3}
  VERSION_RELEASE_RESPONSE_TIME_TEST = {:no_need => 1, :passed => 2, :failed => 3}
  VERSION_RELEASE_SONAR_CODES_CHECK = {:not => 1, :yes => 2, :no => 3}
  VERSION_RELEASE_APP_STANDBY_TEST = {:no_need => 1, :passed => 2, :failed => 3}
  VERSION_RELEASE_MONKEY_72_TEST = {:no_need => 1, :passed => 2, :failed => 3}
  VERSION_RELEASE_MEMORY_LEAK_TEST = {:no_need => 1, :passed => 2, :failed => 3}
  VERSION_RELEASE_CTS_TEST = {:no_need => 1, :passed => 2, :failed => 3}
  VERSION_RELEASE_CTS_VERIFIER_TEST = {:no_need => 1, :passed => 2, :failed => 3}
  VERSION_RELEASE_INTERIOR_INVOKE_WARNING = {:not_involved => 1, :passed => 2, :failed => 3}
  VERSION_RELEASE_RELATED_INVOKE_WARNING = {:not_involved => 1, :passed => 2, :failed => 3}
  VERSION_RELEASE_SDK_REVIEW = {:no_need => 1, :passed => 2, :failed => 3}
  VERSION_RELEASE_UED_CONFIRM = {:passed => 1, :failed => 2}
  VERSION_RELEASE_MODE = {:apk => 1, :zip => 2}
  VERSION_RELEASE_TRANSLATE_SYNC = {:not_involved => 1, :passed => 2, :failed => 3}
  VERSION_RELEASE_OUTPUT_RECORD_SYNC = {:not_involved => 1, :passed => 2, :failed => 3}
  VERSION_RELEASE_APP_DATA_TEST = {:not_involved => 1, :passed => 2, :failed => 3}
  VERSION_RELEASE_APP_LAUNCH_TEST = {:passed => 1, :failed => 2}
  VERSION_RELEASE_TRANSLATE_AUTOCHECK_RESULT = {:passed => 1, :failed => 2}

  enum status: VERSION_RELEASE_STATUS

  # def status
  #   read_attribute_before_type_cast :status
  # end

  # Define Workflow
  aasm :column => :status, :enum => true, :logger => Rails.logger do
    state :submitted, :initial => true
    state :ued_accepted, :ued_half_accepted
    state :sqa_accepted, :sqa_half_accepted
    state :refused
    state :releasing, :completed, :rereleasing

    event :flow_to_ued, :guards => [:flow?, :is_ued_user?] do
      transitions :from => :submitted, :to => [:ued_accepted, :ued_half_accepted, :refused]
    end

    event :flow_to_sqa, :guards => [:flow?, :is_sqa_user?] do
      transitions :from => [:ued_accepted, :ued_half_accepted], :to => [:sqa_accepted, :sqa_half_accepted, :refused]
    end

    event :do_release do
      transitions :from => :submitted, :to => :releasing, :unless => :flow?
      transitions :from => [:sqa_half_accepted, :sqa_accepted], :to => :releasing
      transitions :from => [:releasing, :rereleasing], :to => :releasing
    end

    event :do_complete do
      transitions :from => [:releasing, :rereleasing], :to => :completed, :after => [:update_failed_count, :update_childrens_parent_id]
    end

    event :do_rerelease do
      transitions :from => :completed, :to => :rereleasing
    end
  end

  def self.find_parent(vid, category)
    return if vid.nil? || category.to_i != consts[:category][:adapt]
    version_parent_id =Version.find(vid).find_parent_id
    joins(:version).where(%[
      version_releases.category = 1 AND version_releases.status = 5 AND
      (version_releases.version_id = ? OR versions.parent_id = ?)],
    version_parent_id, version_parent_id).first
  end

  def is_ued_user?
    User.current.admin? || (project || version.project).users_of_role(21).where('users.id = ?', User.current.id).present?
  rescue
    false
  end

  # change sqa to CeShiFuZeRen
  def is_sqa_user?
    User.current.admin? || User.current.has_role?(15)
  rescue
    false
  end


  # Role: APP-UED, role_id => 21
  def ued_user
    (project || version.project).users_of_role(21).active.reorder('members.created_on ASC').first if flow?
  end

  # Role: CeShiFuZeRen, role_id => 15
  def sqa_users
    aimed_project.users_of_role(15).active.reorder('members.created_on ASC') if flow?
  end

  def sqa_user
    sqa_users.try :first
  end

  def show_by(*category)
    return true if category.blank?
    category.include? self.category
  end

  def spec_id
    version.try(:spec_id)
  end

  # Check if this release need to flow
  def flow?
    self.class.consts[:category].slice(:complete, :adapt).values.include? category
  end

  # aimed_project means this release will release to which projects
  def aimed_project
    Project.find_by(:id => tested_mobile.to_i) if flow?
  end

  def can_flow?
    flow? && (may_flow_to_ued? || may_flow_to_sqa?)
  end

  def allowed_statuses
    aasm.states(:permitted => true).map(&:name)
  end

  def old_release_pathes
    main_version_id = version.find_parent_id

    scope = SpecVersion.joins(spec: :project)
                       .where(:specs => {:for_new => [1, 2]})
                       .where(:specs => {:freezed => false})
                       .where(:spec_versions => {:version_id => main_version_id})
                       .where(:spec_versions => {:freezed => false})

    # if VERSION_RELEASE_CATEGORY.values_at(:complete, :adapt).include?(category)
    #   scope = scope.where(:projects => {:id => tested_mobile.split(',')})
    # end

    scope.where("LENGTH(TRIM(REPLACE(REPLACE(spec_versions.release_path, CHAR(10),''), CHAR(13),''))) > 0")
         .select("release_path,
                  GROUP_CONCAT(DISTINCT specs.for_new) as release_ways,
                  GROUP_CONCAT(DISTINCT projects.id) as project_ids")
         .group("release_path")
  end

  def new_release_pathes
    main_version = version.parent || version
    ReposHelper.get_repos_by_version_id(main_version.id).map{|repo| repo["repo_url"]}.uniq
  end

  def log_folder
    time = created_at || DateTime.now
    # Rails.root.join('files', "#{time.strftime("%Y/%m")}/release_log/#{id}")
    Attachment::ROOT_DIR.join('files', "#{time.strftime("%Y/%m")}/release_log/#{id}")
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

  VersionReleaseNote = Struct.new(:author_id, :old_status, :status, :content, :created_at) do
    def author
      User.find_by(:id => author_id)
    end
  end

  def notes=(text)
    self.note.push({
      :author_id => User.current.id, :old_status => status_was,
      :status => status, :content => text, :created_at => Time.now
    })
  end

  def notes
    note.map { |n| VersionReleaseNote.new *n.values }
  end

  def update_failed_count
    failed_release_count = result.count{ |r| r[:status] == 0 }
    update_column :failed_count, failed_release_count if (failed_release_count > 0 || failed_count.present?)
  end

  def update_childrens_parent_id
    find_children.update_all :parent_id => id
  end

  # For new adapt release to find parent: complete release
  def find_parent
    VersionRelease.find_parent(version_id, category)
  end

  # Find all the children (include having no parent_id but belongs to this)
  def find_children
    return self.class.none if category != 1
    pid = self.version.find_parent_id
    self.class.joins(:version).where(%[
      version_releases.category = 2 AND (version_releases.version_id = ? OR versions.parent_id = ?)
    ], pid, pid)
  end

  #current user is test manager
  def is_tm?
    @tested_mobile = Project.where(:id => tested_mobile.to_s.split(','))
    # @tested_mobile.users_of_role(15).map(&:id).include?(User.current.id) if @tested_mobile.present?
    return false unless @tested_mobile.present?
    @tested_mobile.each { |p|
      return true if p.users_of_role(15).map(&:id).include?(User.current.id)
    }
  end

  private

  def check_ued_and_sqa_user_valid
    return if persisted? || !flow?
    errors.add :base, l(:version_release_notice_ued_user_invalid, :name => version.project.name) if ued_user.nil?
    errors.add :base, l(:version_release_notice_sqa_user_invalid, :name => aimed_project.name) if sqa_user.nil?
  end

  def add_project
    self.project = version.project
  end

  def set_parent_id
    self.parent_id = find_parent
  end

  def save_attachments_to_production_documents
    return if category != VERSION_RELEASE_CATEGORY[:complete] || !project.module_enabled?(:documents)
    attas_h = attachments.inject({}) do |r, e|
      k = e.filename.first.upcase
      r[k] = (r[k] || []) << e.id
      r
    end

    doc = project.documents.new(:title => (version.spec.name + '_' + version.name), :description => '产品发布自动创建')
    DocumentCategory.active.for_production.each do |cate|
      char = cate.real_name.split('-').second
      attas_h.fetch(char){[]}.each do |atta_id|
        doc.document_attachments.new(:category_id => cate.id, :attachment_id => atta_id)
      end
    end

    doc.document_attachments.size > 0 ? doc.save : doc = nil
  end

  def do_something_if_can
    update_has_problem           if sqa_half_accepted?
    add_to_version_release_job   if may_do_release? && !releasing? # release
    send_notification(ued_user)  if flow? && submitted? # send to UED
    send_notification(sqa_users) if flow? && (ued_accepted? || ued_half_accepted?) # send to SQA
  end

  def add_to_version_release_job
    if Rails.env.production?
      logger.info("add_to_version_release_job (id = #{self.id})")
      VersionReleaseJob.perform_later(self.id)
    end
  end

  def send_notification(user)
    Notification.version_release_flow_notification(user, :release => self)
    Mailer.version_release_flow_notification(user, :release => self).deliver
  end

  def update_has_problem
    if category != 3 && sqa_half_accepted?
      self.update_columns(has_problem: true)
    end
  end

end

