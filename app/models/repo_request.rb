class RepoRequest < ActiveRecord::Base
  include AASM

  serialize :write_users, Array
  serialize :read_users, Array
  serialize :submit_users, Array

  has_many :alter_records, :as => :alter_for, :dependent => :destroy, :inverse_of => :alter_for
  belongs_to :author, :class_name => 'User'
  belongs_to :project, :class_name => 'Project'
  belongs_to :version, :class_name => 'Version'

  REPO_REQUEST_STATUS = {:submitted => 1, :confirmed => 2, :refused => 3, :failed => 4, :successful => 5, :agreed => 6, :abandoned => 7}.freeze
  REPO_REQUEST_SERVER_IP = %w(19.9.0.146 19.9.0.151 19.9.0.152).freeze
  REPO_REQUEST_CATEGORY = {:project_branch => 1, :production_branch => 2, :production_repo => 3}
  REPO_REQUEST_PRODUCTION_TYPE = %w(apk other china oversea).freeze
  # qp: quantity_production; ge: government_enterprise
  REPO_REQUEST_USE = {:qp=> 1, :cta => 2, :cmcc => 3, :cts => 4, :ge => 5, :other => 6, :pd=> 7, :tf => 8}
  JOB_NAME = {1 => "auto_create_project_branch_based_xml",
              2 => "auto_create_branch_and_set_git_authority_for_apk",
              3 => "auto_create_single_repository_for_apk",
              4 => "test_for_amige"}.freeze
  TIME_SET = {:test => {end_interval: 55, interval: 50, sleep: 60},
              :production => {end_interval: 25, interval: 20, sleep: 15}}

  validates :author_id, :status, presence: true
  validates :project_id, presence: true, if: :need_project?
  validates :repo_name, presence: true, if: :not_apk?
  validates :android_repo, :use, :notes, presence: true, if: :project_branch?
  validates :branch, presence: true, if: :validate_branch?
  validates :write_users, :submit_users, presence: true, if: :production_repo?
  validates :version_id, presence: true, if: :validate_version_id?
  #validates :tag_number, presence: true, if: :validate_tag_number?

  before_save :get_server_ip, :abandon_repo
  after_save :do_something, :send_notification

  scope :success_requests, -> { where(:status => REPO_REQUEST_STATUS[:successful]) }
  scope :software_records, -> {
    joins("INNER JOIN projects ON projects.id = repo_requests.project_id
           LEFT JOIN members ON members.project_id = projects.id AND members.user_id = #{User.current.id}
           LEFT JOIN member_roles AS roles ON members.id = roles.member_id")
    .where("repo_requests.status = 6 AND repo_requests.category = 1 AND roles.role_id = 11") }

  enum status: REPO_REQUEST_STATUS

  aasm :column => :status, :enum => true, :logger => Rails.logger do
    state :submitted, :initial => true
    state :confirmed, :refused, :failed, :successful, :abandoned, :agreed

    event :do_refuse, :guards => [:flow?]do
      transitions :from => :submitted, :to => :refused
    end

    event :do_confirm, :guards => [:flow?] do 
      transitions :from => :submitted, :to => :confirmed
    end

    event :do_fail do
      transitions :from => [:submitted, :confirmed], :to => :failed, :after => [:send_notification]
    end

    event :do_success do
      transitions :from => [:submitted, :confirmed], :to => :successful, :after => [:send_notification]
    end

  end

  def flow?
    category != 2
  end

  def project_branch?
    category == 1
  end

  def production_repo?
    category == 3
  end

  def branch?
    ([1, 2]).include?(category)
  end

  def validate_branch?
    (category == 1 && confirmed?) || category == 2
  end

  def validate_version_id?
    category == 2 || (category == 1)
  end

  def validate_tag_number?
    category == 1 && production_type == "oversea"
  end

  def need_project?
    branch? || (category == 3 && production_type != 'other')
  end

  def not_apk?
    category == 3 && production_type == "other"
  end

  def writer
    User.where(id: self.write_users)
  end

  def reader
    User.where(id: self.read_users)
  end

  def submitter
    User.where(id: self.submit_users)
  end

  def can_edit?
    user = User.current
    key = RepoRequest::REPO_REQUEST_CATEGORY.key(category).to_s
    if submitted?
      if user.can_do?("judge", key)
        can = user.can_do?("apply", key) && submitted?
      end  

      can &&= submitted?
    elsif agreed?
      can = project.users_of_role(11).map(&:id).include?(User.current.id)
    end
    return can
  end

  def get_server_ip
    data = [] 
    case category
    when 1
      return true unless server_ip.blank?
      errors.add(:server_ip, "根据版本未找到该安卓代码仓对应的服务器地址")
      false
    when 2
      return true unless server_ip.blank?
      errors.add(:server_ip, "根据版本未找到该产品代码仓对应的服务器地址") 
      false
    when 3
      if server_ip.blank? && User.current.can_do?("judge", RepoRequest::REPO_REQUEST_CATEGORY.key(category).to_s)
        errors.add(:server_ip, "不能为空")
        result = false
      else 
        result = true
      end 
      data << server_ip if server_ip.present?      
    end

    return result
  end

  def do_something
    if (category == 2 && submitted?) || (([1, 3]).include?(category) && confirmed?)
      RepoRequestJob.perform_later(self.build_api_params, self.id)
    end
  end

  def abandon_repo
    if abandoned?
      transaction do 
        @repo = Repo.where(name: android_repo.to_s, branch: branch.to_s, category: 10).last
        return false unless @repo.present?
        Repo.unlink(project.id, @repo.id)
        @repo.update(abandoned: true)
      end
    end
  end

  def send_notification
    if %w(submitted agreed refused successful failed abandoned).include?(status) #|| (category != 2 && submitted?)
      Notification.repo_request_notification(self)
    end
  end

  def build_api_params
    api_params = {}
    api_params[:server_ip] = server_ip
    if category == 1
      api_params[:android_repository] = android_repo
      api_params[:package_repository] = package_repo
      api_params[:project_name] = project.identifier.first(7)
      api_params[:tag_number] = version.try(:name)
      api_params[:new_branch_name] = branch
      api_params[:root_manifest_path] = "/home/android/create_project_branch"    
      api_params[:user_list] = EmailAddress.get_email_name(write_users + read_users).join(",")
      api_params[:new_group_name] = api_params[:user_list].present? ? (api_params[:new_branch_name] + "_write") : ""
    elsif category == 2
      api_params[:repository_name] = project.name
      api_params[:branch_name] = branch
      api_params[:write_uesr_list] = EmailAddress.get_email_name(write_users).join(",")
      api_params[:write_group_name] = api_params[:write_uesr_list].present? ? (api_params[:branch_name] + "_write") : ""
      api_params[:submit_uesr_list] = EmailAddress.get_email_name(submit_users).join(",")
      api_params[:submit_group_name] = api_params[:submit_uesr_list].present? ? (api_params[:branch_name] + "_submit") : ""
      api_params[:base_commit] = version.fullname 
    elsif category == 3
      api_params[:repository_name] = production_type != "other" ? project.name : repo_name 
      api_params[:readuser] = EmailAddress.get_email_name(read_users).join(",")
      api_params[:readgroup] = api_params[:readuser].present? ? (api_params[:repository_name] + "_read") : ""
      api_params[:writeuser] = EmailAddress.get_email_name(write_users).join(",")
      api_params[:writegroup] = api_params[:writeuser].present? ? (api_params[:repository_name] + "_write") : ""
      api_params[:submituser] = EmailAddress.get_email_name(submit_users).join(",")
      api_params[:submitgroup] = api_params[:submituser].present? ? (api_params[:repository_name] + "_submit") : ""
    end
    return api_params
  end

  def spm_judge?
    !new_record? && submitted? && category == 1
  end

  def read_perm?
    case category.to_i
    when 3
      true
    else
      false
    end
  end

  def write_perm?
    case category.to_i
    when 1
      agreed?
    else
      true
    end
  end

  def submit_perm?
    case category.to_i
    when 1
      false
    else
      true
    end
  end

  def author?
    author_id == User.current.id
  end

  def show_in_form?(col, type)
    case col
    when :server_ip
      judge = User.current.can_do?("judge", RepoRequest::REPO_REQUEST_CATEGORY.key(category).to_s)
      type == category && judge
    when :production_type
      if category == 1
        new_record? && type == category
      else
        type == category
      end
    when :repo_name
      category == 3 && !(production_type == "apk" || production_type == 'management')
    when :project_id
      if category == 1
        new_record?
      elsif category == 3
        production_type == "apk" || production_type == 'management'
      else
        true
      end
    when :version_id
      if category == 2
        true
      elsif category == 1 
        new_record?
      end
    # when :tag_number
    #   category == 1 && production_type ! "china" && new_record?
    when :android_repo, :package_repo, :use
      category == 1 && new_record?
    when :branch
      if category == 1
        agreed?
      elsif category == 2
        true
      else
        false
      end
    end
  end

  def init_alter(notes = "")
    @current_alter ||= AlterRecord.new(:alter_for => self, :user => User.current)
  end

  # Returns the current journal or nil if it's not initialized
  def current_alter
    @current_alter
  end

  def create_alter
    if current_alter
      current_alter.save
    end
  end

  def altered_attribute_names
    names = ["notes"]
  end

  def generate_notes_alter_record(notes)
    if category == 1 || category == 3
      @alter_record = AlterRecord.create(alter_for_id: self.id, alter_for_type: self.class.name, user_id: User.current.id, notes: notes)
      @alter_record.details.create(prop_key: "notes", value: notes)
    end
  end

  def fullpath
    case category
      when 1
        ["ssh://" + self.server_ip.to_s + ":29418", self.android_repo, self.branch]
    end.join('/')
  end

  def visible_alter_records(prop_key = nil)
    AlterRecord.includes(:details).where(alter_for_id: self.id).where(alter_record_details: {prop_key: "notes"})
  end
end
