# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require "digest/sha1"

class User < Principal
  include Redmine::SafeAttributes
  include HTTParty

  # Different ways of displaying/sorting users
  USER_FORMATS = {
    :firstname_lastname => {
        :string => '#{firstname} #{lastname}',
        :order => %w(firstname lastname id),
        :setting_order => 1
      },
    :firstname_lastinitial => {
        :string => '#{firstname} #{lastname.to_s.chars.first}.',
        :order => %w(firstname lastname id),
        :setting_order => 2
      },
    :firstinitial_lastname => {
        :string => '#{firstname.to_s.gsub(/(([[:alpha:]])[[:alpha:]]*\.?)/, \'\2.\')} #{lastname}',
        :order => %w(firstname lastname id),
        :setting_order => 2
      },
    :firstname => {
        :string => '#{firstname}',
        :order => %w(firstname id),
        :setting_order => 3
      },
    :lastname_firstname => {
        :string => '#{lastname} #{firstname}',
        :order => %w(lastname firstname id),
        :setting_order => 4
      },
    :lastnamefirstname => {
        :string => '#{lastname}#{firstname}',
        :order => %w(lastname firstname id),
        :setting_order => 5
      },
    :lastname_comma_firstname => {
        :string => '#{lastname}, #{firstname}',
        :order => %w(lastname firstname id),
        :setting_order => 6
      },
    :lastname => {
        :string => '#{lastname}',
        :order => %w(lastname id),
        :setting_order => 7
      },
    :username => {
        :string => '#{login}',
        :order => %w(login id),
        :setting_order => 8
      },
  }

  MAIL_NOTIFICATION_OPTIONS = [
    ['all', :label_user_mail_option_all],
    ['selected', :label_user_mail_option_selected],
    ['only_my_events', :label_user_mail_option_only_my_events],
    ['only_assigned', :label_user_mail_option_only_assigned],
    ['only_owner', :label_user_mail_option_only_owner],
    ['none', :label_user_mail_option_none]
  ]

  KEY = "test"
  CATEGORY = %w(member external supervisor manager majordomo vice_president)
  DEFAULT_PASSWORD = '123456'

  has_and_belongs_to_many :groups,
                          :join_table   => "#{table_name_prefix}groups_users#{table_name_suffix}",
                          :after_add    => Proc.new {|user, group| group.user_added(user)},
                          :after_remove => Proc.new {|user, group| group.user_removed(user)}
  has_many :changesets, :dependent => :nullify
  has_one :preference, :dependent => :destroy, :class_name => 'UserPreference'
  has_one :rss_token, lambda {where "action='feeds'"}, :class_name => 'Token'
  has_one :api_token, lambda {where "action='api'"}, :class_name => 'Token'
  has_one :resourcing
  has_one :email_address, lambda {where :is_default => true}, :autosave => true
  has_many :email_addresses, :dependent => :delete_all
  has_many :risks, :dependent => :destroy
  has_many :conditions, :dependent => :destroy
  has_many :condition_histories, :dependent => :destroy
  has_many :spec_alter_records, :dependent => :destroy
  has_many :compare_models, :dependent => :destroy
  has_many :report_condition_histories, :dependent => :destroy
  has_many :default_values, :dependent => :destroy
  belongs_to :auth_source
  belongs_to :dept, class_name: "Dept", foreign_key: "orgNo", :primary_key => "orgNo"
  has_many :subordinates, class_name: "User", foreign_key: "group_bmjl_id", :primary_key => "login"
  belongs_to :superior, class_name: "User", foreign_key: "group_bmjl_id", :primary_key => "login"
  has_many :tasks, :class_name => "Task", foreign_key: "assigned_to_id", :primary_key => "id"
  has_many :custom_permissions, foreign_key: "user_id"
  has_many :views, :class_name => "ViewRecord", foreign_key: 'user_id'
  has_many :okrs_records, :class_name => "OkrsRecord", foreign_key: 'author_id'
  has_many :favors, :class_name => "UserFavor", foreign_key: 'user_id'

  scope :logged, lambda { where("#{User.table_name}.status <> #{STATUS_ANONYMOUS}") }
  scope :status, lambda {|arg| where(arg.blank? ? nil : {:status => arg.to_i})}

  acts_as_customizable
  mount_uploader :picture, Uploader::AvatarUploader

  attr_accessor :password, :password_confirmation, :generate_password
  attr_accessor :last_before_login_on
  attr_accessor :remote_ip
  attr_accessor :crop_size

  # Prevents unauthorized assignments
  attr_protected :login, :admin, :password, :password_confirmation, :hashed_password

  LOGIN_LENGTH_LIMIT = 60
  MAIL_LENGTH_LIMIT = 60

  validates_presence_of :login, :firstname, :if => Proc.new { |user| !user.is_a?(AnonymousUser) }
  validates_uniqueness_of :login, :if => Proc.new { |user| user.login_changed? && user.login.present? }, :case_sensitive => false
  # Login must contain letters, numbers, underscores only

  validates_format_of :login, :with => /\A[a-z0-9_\-@\.]*\z/i
  validates_length_of :login, :maximum => LOGIN_LENGTH_LIMIT
  validates_length_of :firstname, :lastname, :maximum => 30
  validates_inclusion_of :mail_notification, :in => MAIL_NOTIFICATION_OPTIONS.collect(&:first), :allow_blank => true
  validates :login, :uniqueness => true
  validate :validate_password_length
  validate do
    if password_confirmation && password != password_confirmation
      errors.add(:password, :confirmation)
    end
  end
  validate :avatar_size

  self.valid_statuses = [STATUS_ACTIVE, STATUS_REGISTERED, STATUS_LOCKED]

  before_validation :instantiate_email_address
  before_create :set_mail_notification, :generate_pinyin
  before_save   :generate_password_if_needed, :update_hashed_password
  before_destroy :remove_references_before_destroy
  after_save :update_notified_project_ids, :destroy_tokens, :deliver_security_notification
  after_destroy :deliver_security_notification

  scope :in_group, lambda {|group|
    group_id = group.is_a?(Group) ? group.id : group.to_i
    where("#{User.table_name}.id IN (SELECT gu.user_id FROM #{table_name_prefix}groups_users#{table_name_suffix} gu WHERE gu.group_id = ?)", group_id)
  }
  scope :not_in_group, lambda {|group|
    group_id = group.is_a?(Group) ? group.id : group.to_i
    where("#{User.table_name}.id NOT IN (SELECT gu.user_id FROM #{table_name_prefix}groups_users#{table_name_suffix} gu WHERE gu.group_id = ?)", group_id)
  }
  scope :sorted, lambda { order(*User.fields_for_order_statement)}
  scope :having_mail, lambda {|arg|
    addresses = Array.wrap(arg).map {|a| a.to_s.downcase}
    if addresses.any?
      joins(:email_addresses).where("LOWER(#{EmailAddress.table_name}.address) IN (?)", addresses).uniq
    else
      none
    end
  }

  scope :category, -> (categories) {
    sql_proc = -> (arr) {arr.map{|e| "(LENGTH(depts.#{e}) > 0 AND users.empId = depts.#{e})"}.join(" OR ")}
    sql = {
      :member         => "users.empId IS NOT NULL",
      :external       => "users.empId IS NULL",
      :supervisor     => sql_proc.call(%w(supervisor_number supervisor2_number)),
      :manager        => sql_proc.call(%w(manager_number sub_manager_number manager2_number sub_manager2_number)),
      :majordomo      => sql_proc.call(%w(majordomo_number sub_majordomo_number)),
      :vice_president => sql_proc.call(%w(vice_president_number vice_president2_number))
    }
    sqls = Array(categories).map{|cate| "(#{sql[cate.to_sym]})"}.join(" OR ")
    joins("left join depts on depts.orgNo = users.orgNo").where sqls
  }

  scope :export_staffs, lambda { |nos|
    select_sql = (1..Dept.max_level).map{|i| "CASE WHEN depts.leve = #{i} THEN depts.orgNm ELSE '' END dept#{i}"}.join(',')
    joins("left join depts on depts.orgNo = users.orgNo").order("depts.orgNo").select("#{select_sql},depts.parentNm,depts.parentNo,users.firstname username,users.empId").where("depts.id in (#{nos})")
  }

  def set_mail_notification
    self.mail_notification = Setting.default_notification_option if self.mail_notification.blank?
    true
  end

  def generate_pinyin
    self.pinyin = to_pinyin
  end

  def update_hashed_password
    # update hashed_password if password was set
    if self.password && self.auth_source_id.blank?
      salt_password(password)
    end
  end

  alias :base_reload :reload
  def reload(*args)
    @name = nil
    @projects_by_role = nil
    @membership_by_project_id = nil
    @notified_projects_ids = nil
    @notified_projects_ids_changed = false
    @builtin_role = nil
    @visible_project_ids = nil
    @managed_roles = nil
    base_reload(*args)
  end

  def mail
    email_address.try(:address)
  end

  def mail=(arg)
    email = email_address || build_email_address
    email.address = arg
  end

  def mail_changed?
    email_address.try(:address_changed?)
  end

  def mails
    email_addresses.pluck(:address)
  end

  def self.find_or_initialize_by_identity_url(url)
    user = where(:identity_url => url).first
    unless user
      user = User.new
      user.identity_url = url
    end
    user
  end

  def identity_url=(url)
    if url.blank?
      write_attribute(:identity_url, '')
    else
      begin
        write_attribute(:identity_url, OpenIdAuthentication.normalize_identifier(url))
      rescue OpenIdAuthentication::InvalidOpenId
        # Invalid url, don't save
      end
    end
    self.read_attribute(:identity_url)
  end

  # Returns the user that matches provided login and password, or nil
  def self.try_to_login(login, password, active_only=true)
    login = login.to_s
    password = password.to_s

    # Make sure no one can sign in with an empty login or password
    return nil if login.empty? || password.empty?
    user = find_by_login(login)
    if user
      # user is already in local database
      return nil unless user.check_password?(password)
      return nil if !user.active? && active_only
    else
      # user is not yet registered, try to authenticate with available sources
      attrs = AuthSource.authenticate(login, password)
      if attrs
        user = new(attrs)
        user.login = login
        user.language = Setting.default_language
        if user.save
          user.reload
          logger.info("User '#{user.login}' created from external auth source: #{user.auth_source.type} - #{user.auth_source.name}") if logger && user.auth_source
        end
      end
    end
    user.update_column(:last_login_on, Time.now) if user && !user.new_record? && user.active?
    user
  rescue => text
    raise text
  end

  # Returns the user who matches the given autologin +key+ or nil
  def self.try_to_autologin(key)
    user = Token.find_active_user('autologin', key, Setting.autologin.to_i)
    if user
      user.update_column(:last_login_on, Time.now)
      user
    end
  end

  def self.name_formatter(formatter = nil)
    USER_FORMATS[formatter || Setting.user_format] || USER_FORMATS[:lastnamefirstname]
  end

  # Returns an array of fields names than can be used to make an order statement for users
  # according to how user names are displayed
  # Examples:
  #
  #   User.fields_for_order_statement              => ['users.login', 'users.id']
  #   User.fields_for_order_statement('authors')   => ['authors.login', 'authors.id']
  def self.fields_for_order_statement(table=nil)
    table ||= table_name
    name_formatter[:order].map {|field| "#{table}.#{field}"}
  end

  # Return user's full name for display
  def name(formatter = nil)
    f = self.class.name_formatter(formatter)
    if formatter
      eval('"' + f[:string] + '"')
    else
      @name ||= eval('"' + f[:string] + '"')
    end
    #self.lastname + self.firstname

  end

  def active?
    self.status == STATUS_ACTIVE
  end

  def registered?
    self.status == STATUS_REGISTERED
  end

  def locked?
    self.status == STATUS_LOCKED
  end

  def activate
    self.status = STATUS_ACTIVE
  end

  def register
    self.status = STATUS_REGISTERED
  end

  def lock
    self.status = STATUS_LOCKED
  end

  def activate!
    update_attribute(:status, STATUS_ACTIVE)
  end

  def register!
    update_attribute(:status, STATUS_REGISTERED)
  end

  def lock!
    update_attribute(:status, STATUS_LOCKED)
  end

  # Returns true if +clear_password+ is the correct user's password, otherwise false
  def check_password?(clear_password)
    if auth_source_id.present?
      auth_source.authenticate(self.login, clear_password)
    else
      User.hash_password("#{salt}#{User.hash_password clear_password}") == hashed_password
    end
  end

  # Generates a random salt and computes hashed_password for +clear_password+
  # The hashed password is stored in the following form: SHA1(salt + SHA1(password))
  def salt_password(clear_password)
    self.salt = User.generate_salt
    self.hashed_password = User.hash_password("#{salt}#{User.hash_password clear_password}")
    self.passwd_changed_on = Time.now.change(:usec => 0)
  end

  # Does the backend storage allow this user to change their password?
  def change_password_allowed?
    return true if auth_source.nil?
    return auth_source.allow_password_changes?
  end

  # Returns true if the user password has expired
  def password_expired?
    period = Setting.password_max_age.to_i
    if period.zero?
      false
    else
      changed_on = self.passwd_changed_on || Time.at(0)
      changed_on < period.days.ago
    end
  end

  def must_change_password?
    (must_change_passwd? || password_expired?) && change_password_allowed?
  end

  def generate_password?
    generate_password == '1' || generate_password == true
  end

  # Generate and set a random password on given length
  def random_password(length=40)
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    chars -= %w(0 O 1 l)
    password = ''
    length.times {|i| password << chars[SecureRandom.random_number(chars.size)] }
    self.password = password
    self.password_confirmation = password
    self
  end

  def pref
    self.preference ||= UserPreference.new(:user => self)
  end

  def time_zone
    @time_zone ||= (self.pref.time_zone.blank? ? nil : ActiveSupport::TimeZone[self.pref.time_zone])
  end

  def emoji_font
    self.pref[:emoji_font] ||= 'apple'
  end

  def force_default_language?
    Setting.force_default_language_for_loggedin?
  end

  def language
    if force_default_language?
      Setting.default_language
    else
      super
    end
  end

  def wants_comments_in_reverse_order?
    self.pref[:comments_sorting] == 'desc'
  end

  # Return user's RSS key (a 40 chars long string), used to access feeds
  def rss_key
    if rss_token.nil?
      create_rss_token(:action => 'feeds')
    end
    rss_token.value
  end

  # Return user's API key (a 40 chars long string), used to access the API
  def api_key
    if api_token.nil?
      create_api_token(:action => 'api')
    end
    api_token.value
  end

  # Generates a new session token and returns its value
  def generate_session_token
    token = Token.create!(:user_id => id, :action => 'session')
    token.value
  end

  # Returns true if token is a valid session token for the user whose id is user_id
  def self.verify_session_token(user_id, token)
    return false if user_id.blank? || token.blank?

    scope = Token.where(:user_id => user_id, :value => token.to_s, :action => 'session')
    if Setting.session_lifetime?
      scope = scope.where("created_on > ?", Setting.session_lifetime.to_i.minutes.ago)
    end
    if Setting.session_timeout?
      scope = scope.where("updated_on > ?", Setting.session_timeout.to_i.minutes.ago)
    end
    scope.update_all(:updated_on => Time.now) == 1
  end

  # Return an array of project ids for which the user has explicitly turned mail notifications on
  def notified_projects_ids
    @notified_projects_ids ||= memberships.select {|m| m.mail_notification?}.collect(&:project_id)
  end

  def notified_project_ids=(ids)
    @notified_projects_ids_changed = true
    @notified_projects_ids = ids.map(&:to_i).uniq.select {|n| n > 0}
  end

  # Updates per project notifications (after_save callback)
  def update_notified_project_ids
    if @notified_projects_ids_changed
      ids = (mail_notification == 'selected' ? Array.wrap(notified_projects_ids).reject(&:blank?) : [])
      members.update_all(:mail_notification => false)
      members.where(:project_id => ids).update_all(:mail_notification => true) if ids.any?
    end
  end

  def user_custom_permission_manage
    self.custom_permissions.where(locked: false, permission_type: %w(project_branch_manage production_branch_manage production_repo_manage)).map(&:permission_type)
  end

  def user_custom_permission_apply
    self.custom_permissions.where(locked: false, permission_type: CustomPermission::CUSTOM_PERMISSION_COMMON).map(&:permission_type)
  end

  def user_custom_permission_judge
    self.custom_permissions.where(locked: false, permission_type: %w(project_branch_judge production_repo_judge)).map(&:permission_type)
  end

  def can_do?(type, single)
    case type
    when "manage"
      if single.present?
        context = [single, type].join("_")
        self.user_custom_permission_manage.include?(context)
      else
        self.user_custom_permission_manage.present? || self.admin?
      end
    when "apply"
      if single.present?
        context = [single, type].join("_")
        self.user_custom_permission_apply.include?(context) || self.can_do?("manage", single) || self.admin?
      else
        self.user_custom_permission_apply.present? || self.can_do?("manage", nil) || self.admin?
      end
    when "judge"
      if single.present?
        context = [single, type].join("_")
        self.user_custom_permission_judge.include?(context) || self.admin?
      else
        self.user_custom_permission_judge.present? || self.admin?
      end
    end
  end
  private :update_notified_project_ids

  def valid_notification_options
    self.class.valid_notification_options(self)
  end

  # Only users that belong to more than 1 project can select projects for which they are notified
  def self.valid_notification_options(user=nil)
    # Note that @user.membership.size would fail since AR ignores
    # :include association option when doing a count
    if user.nil? || user.memberships.length < 1
      MAIL_NOTIFICATION_OPTIONS.reject {|option| option.first == 'selected'}
    else
      MAIL_NOTIFICATION_OPTIONS
    end
  end

  # Find a user account by matching the exact login and then a case-insensitive
  # version.  Exact matches will be given priority.
  def self.find_by_login(login)
    login = Redmine::CodesetUtil.replace_invalid_utf8(login.to_s)
    if login.present?
      # First look for an exact match
      user = where(:login => login).detect {|u| u.login == login}
      unless user
        # Fail over to case-insensitive if none was found
        user = where("LOWER(login) = ?", login.downcase).first
      end
      user
    end
  end

  def self.find_by_rss_key(key)
    Token.find_active_user('feeds', key)
  end

  def self.find_by_api_key(key)
    Token.find_active_user('api', key)
  end

  # Makes find_by_mail case-insensitive
  def self.find_by_mail(mail)
    having_mail(mail).first
  end

  # Returns true if the default admin account can no longer be used
  def self.default_admin_account_changed?
    !User.active.find_by_login("admin").try(:check_password?, "admin")
  end

  def to_s
    name
  end

  CSS_CLASS_BY_STATUS = {
    STATUS_ANONYMOUS  => 'anon',
    STATUS_ACTIVE     => 'active',
    STATUS_REGISTERED => 'registered',
    STATUS_LOCKED     => 'locked'
  }

  def css_classes
    "user #{CSS_CLASS_BY_STATUS[status]}"
  end

  # Returns the current day according to user's time zone
  def today
    if time_zone.nil?
      Date.today
    else
      time_zone.today
    end
  end

  # Returns the day of +time+ according to user's time zone
  def time_to_date(time)
    if time_zone.nil?
      time.to_date
    else
      time.in_time_zone(time_zone).to_date
    end
  end

  def logged?
    true
  end

  def anonymous?
    !logged?
  end

  # Returns user's membership for the given project
  # or nil if the user is not a member of project
  def membership(project)
    project_id = project.is_a?(Project) ? project.id : project

    @membership_by_project_id ||= Hash.new {|h, project_id|
      h[project_id] = memberships.where(:project_id => project_id).first
    }
    @membership_by_project_id[project_id]
  end

  # Returns the user's bult-in role
  def builtin_role
    @builtin_role ||= Role.non_member
  end

  # Return user's roles for project
  def roles_for_project(project)
    # No role on archived projects
    return [] if project.nil? || project.archived?
    if membership = membership(project)
      membership.roles.to_a
    elsif project.is_public?
      project.override_roles(builtin_role)
    else
      []
    end
  end

  # Returns a hash of user's projects grouped by roles
  def projects_by_role
    return @projects_by_role if @projects_by_role

    hash = Hash.new([])

    group_class = anonymous? ? GroupAnonymous : GroupNonMember
    members = Member.joins(:project, :principal).
      where("#{Project.table_name}.status <> 9").
      where("#{Member.table_name}.user_id = ? OR (#{Project.table_name}.is_public = ? AND #{Principal.table_name}.type = ?)", self.id, true, group_class.name).
      preload(:project, :roles).
      to_a

    members.reject! {|member| member.user_id != id && project_ids.include?(member.project_id)}
    members.each do |member|
      if member.project
        member.roles.each do |role|
          hash[role] = [] unless hash.key?(role)
          hash[role] << member.project
        end
      end
    end

    hash.each do |role, projects|
      projects.uniq!
    end

    @projects_by_role = hash
  end

  # Returns the ids of visible projects
  def visible_project_ids
    @visible_project_ids ||= Project.visible(self).pluck(:id)
  end

  # Returns the roles that the user is allowed to manage for the given project
  def managed_roles(project)
    if admin?
      @managed_roles ||= Role.givable.to_a
    else
      membership(project).try(:managed_roles) || []
    end
  end

  # Returns true if user is arg or belongs to arg
  def is_or_belongs_to?(arg)
    if arg.is_a?(User)
      self == arg
    elsif arg.is_a?(Group)
      arg.users.include?(self)
    else
      false
    end
  end

  # Return true if the user is allowed to do the specified action on a specific context
  # Action can be:
  # * a parameter-like Hash (eg. :controller => 'projects', :action => 'edit')
  # * a permission Symbol (eg. :edit_project)
  # Context can be:
  # * a project : returns true if user is allowed to do the specified action on this project
  # * an array of projects : returns true if user is allowed on every project
  # * nil with options[:global] set : check if user has at least one role allowed for this action,
  #   or falls back to Non Member / Anonymous permissions depending if the user is logged
  def allowed_to?(action, context, options={}, &block)
    if context && context.is_a?(Project)
      return false unless context.allows_to?(action)
      # Admin users are authorized for anything else
      return true if admin?

      roles = roles_for_project(context)
      return false unless roles
      roles.any? {|role|
        (context.is_public? || role.member?) &&
        role.allowed_to?(action) &&
        (block_given? ? yield(role, self) : true)
      }
    elsif context && context.is_a?(Array)
      if context.empty?
        false
      else
        # Authorize if user is authorized on every element of the array
        context.map {|project| allowed_to?(action, project, options, &block)}.reduce(:&)
      end
    elsif context
      raise ArgumentError.new("#allowed_to? context argument must be a Project, an Array of projects or nil")
    elsif options[:global]
      # Admin users are always authorized
      return true if admin?

      # authorize if user has at least one role that has this permission
      roles = memberships.collect {|m| m.roles}.flatten.uniq
      roles << (self.logged? ? Role.non_member : Role.anonymous)
      roles.any? {|role|
        role.allowed_to?(action) &&
        (block_given? ? yield(role, self) : true)
      }
    else
      false
    end
  end

  # Is the user allowed to do the specified action on any project?
  # See allowed_to? for the actions and valid options.
  #
  # NB: this method is not used anywhere in the core codebase as of
  # 2.5.2, but it's used by many plugins so if we ever want to remove
  # it it has to be carefully deprecated for a version or two.
  def allowed_to_globally?(action, options={}, &block)
    allowed_to?(action, nil, options.reverse_merge(:global => true), &block)
  end

  def allowed_to_view_all_time_entries?(context)
    allowed_to?(:view_time_entries, context) do |role, user|
      role.time_entries_visibility == 'all'
    end
  end

  # Returns true if the user is allowed to delete the user's own account
  def own_account_deletable?
    Setting.unsubscribe? &&
      (!admin? || User.active.where("admin = ? AND id <> ?", true, id).exists?)
  end

  def has_role?(role_id)
    Member.includes(:member_roles).where(user_id: self.id, member_roles: {role_id: role_id}).first.present?
  end

  safe_attributes 'firstname',
    'lastname',
    'mail',
    'mail_notification',
    'notified_project_ids',
    'language',
    'custom_field_values',
    'custom_fields',
    'identity_url',
    'picture',
    'mobile',
    'phone',
    'orgNo',
    'orgNm',
    'qq'


  safe_attributes 'status',
    'auth_source_id',
    'generate_password',
    'must_change_passwd',
    :if => lambda {|user, current_user| current_user.admin?}

  safe_attributes 'group_ids',
    :if => lambda {|user, current_user| current_user.admin? && !user.new_record?}

  # Utility method to help check if a user should be notified about an
  # event.
  #
  # TODO: only supports Issue events currently
  def notify_about?(object)
    if mail_notification == 'all'
      true
    elsif mail_notification.blank? || mail_notification == 'none'
      false
    else
      case object
      when Issue
        case mail_notification
        when 'selected', 'only_my_events'
          # user receives notifications for created/assigned issues on unselected projects
          object.author == self || is_or_belongs_to?(object.assigned_to) || is_or_belongs_to?(object.assigned_to_was)
        when 'only_assigned'
          is_or_belongs_to?(object.assigned_to) || is_or_belongs_to?(object.assigned_to_was)
        when 'only_owner'
          object.author == self
        end
      when News
        # always send to project members except when mail_notification is set to 'none'
        true
      end
    end
  end

  def self.current=(user)
    RequestStore.store[:current_user] = user
  end

  def self.current
    RequestStore.store[:current_user] ||= User.anonymous
  end

  # Returns the anonymous user.  If the anonymous user does not exist, it is created.  There can be only
  # one anonymous user per database.
  def self.anonymous
    anonymous_user = AnonymousUser.first
    if anonymous_user.nil?
      anonymous_user = AnonymousUser.create(:lastname => 'Anonymous', :firstname => '', :login => '', :status => 0)
      raise 'Unable to create the anonymous user.' if anonymous_user.new_record?
    end
    anonymous_user
  end

  # Salts all existing unsalted passwords
  # It changes password storage scheme from SHA1(password) to SHA1(salt + SHA1(password))
  # This method is used in the SaltPasswords migration and is to be kept as is
  def self.salt_unsalted_passwords!
    transaction do
      User.where("salt IS NULL OR salt = ''").each do |user|
        next if user.hashed_password.blank?
        salt = User.generate_salt
        hashed_password = User.hash_password("#{salt}#{user.hashed_password}")
        User.where(:id => user.id).update_all(:salt => salt, :hashed_password => hashed_password)
      end
    end
  end


  ###################

  def self.import(file)
    sheet = Import.open(file)
    import_messages = []
    sheet.each(login: /id/i, name: /姓名/, mail: /邮箱/, status: /状态/) do |hash|
      login = hash[:login]
      name = hash[:name]
      mail = hash[:mail]
      status= hash[:status]

      user = User.find_by_login(login)
      if user.present?
        user.update_attributes(:firstname => name, :mail => mail, :status => status)
      else
        user = User.new
        user.safe_attributes = user.login
        user.login = login
        user.mail = mail
        user.firstname = name
        user.status = status
        user.save
      end
    end
  end

  def add_condition_history(id)
    history = condition_histories.find_or_create_by(from_id: id)
    history.touch
  end

  def add_report_condition_history(id)
    history = report_condition_histories.find_or_create_by(from_id: id)
    history.touch
  end

  def cas_active(id = nil)
    id ||= self.login
    response = HTTParty.get "http://uc.gionee.com/api/service/app/registerUser?appId=41&userId=#{id}"
    response.present?? response.body : nil
  end

  def change_password(old_pass, new_pass)
    return unless User.current.logged?
    ags = {:globalId => self.login, :originalPassword => old_pass, :newPassword => new_pass}
    response = HTTParty.get "http://uc.gionee.com/api/service/user/verifyAndModifyPassword?#{ags.to_param}"
    response.present?? response.body : nil
  end

  def is_developer?
    !is_tester?
  end

  def is_tester?
    org_no = Dept::TEST_DEPT
    self.dept.present? && (self.dept.all_up_levels & org_no).present?
  end

  def is_spm?(project)
    self.admin? || (Role.joins(members: [:project, :user])
                        .where("projects.id = ? AND users.id = ?", project.id, self.id)
                        .pluck(:name) & ["SPM", "售后SQA", "运营商送测SPM"])
                        .present?
  end

  def is_app_spm?(production)
    self.admin? || (production &&
        Role.spm_users("roles.name = 'SPM' and users.id = #{self.id} and projects.id = #{production.id}").count > 0)
  end

  def is_scm?
    self.admin? || %w(30815 30817 33364).include?(self.login)
  end

  def dept_leader
    # User.find_by_empId(self.group_fujingli_empId || self.group_bmjl_empId || self.group_zgfz_empId || self.group_zhuguan_empId || self.group_zongjian_empId)
    User.find_by_empId [:manager_number, :manager2_number, :sub_manager_number, :sub_manager2_number, :majordomo_number].map{|attr| self.dept.send(attr)}.select{|id| id.to_i > 0}.first || 'csl'
  end

  #TODO find dept leader
  def find_okr_approver
    if dept.blank? || dept_leader.blank?
      User.find(602) 
    else
      if dept_leader == self
        User.find_by(empId: dept.parent.vice_president_number) || User.find(602)
      else
        dept_leader
      end
    end
  end

  def is_platform_driver?(project)
    driver = Role.find_by_name(Role::ROLE_PLATFORM_DRIVER)
    return false if driver.nil?
    project.users_of_role(driver.id).include?(self)
  end

  # def condition_of_all_umpirage_apply
  #   users_id = Approval.umpirages.where("object_type = 'user' and user_id = ?", self.id).pluck(:object_id)
  #   depts_id = Approval.umpirages.where("object_type = 'dept' and user_id = ?", self.id).pluck(:object_id)

  #   emp_id = self.empId.blank?? 'cenx' : self.empId
  #   statement = [:manager_number, :manager2_number, :sub_manager_number, :sub_manager2_number, :majordomo_number].map{|attr| %(#{attr.to_s} = '#{emp_id}')}.join(" OR ")
  #   depts_id |= Dept.where("#{statement}").pluck(:id)
  #   if self.admin?
  #     now_is_umpirage_users_id = Issue.where(:status_id => IssueStatus::APPY_UMPIRAGE_STATUS).pluck(:assigned_to_id).compact
  #     all_no_manager_users_id = User.where("status = 1 AND (group_bmjl_id IS NULL OR group_bmjl_id = 0)").pluck(:id)
  #     users_id = users_id | (now_is_umpirage_users_id & all_no_manager_users_id)
  #   end

  #   con = []
  #   con << "issues.assigned_to_id IN \"dept_#{depts_id*'_'}\"" if depts_id.present?
  #   con << "issues.assigned_to_id IN (#{users_id*","})" if users_id.present?
  #   con.join(" OR ")
  # end

  def condition_of_all_umpirage_apply
    umpirage_applys = Issue.select(:id, :assigned_to_id, :umpirage_approver_id, :status_id).where(:status_id => IssueStatus.where(:name => "申请裁决").pluck(:id))
    issues_id = umpirage_applys.where("status_id = 23 AND umpirage_approver_id LIKE CONCAT('%- #{self.id}',char(10),'%')").pluck(:id)

    if self.admin?
      all_no_manager_users_id = umpirage_applys.where(umpirage_approver_id: nil).pluck(:id)
      issues_id = issues_id | all_no_manager_users_id
    end

    con = []
    con << "issues.id IN (#{issues_id*","})" if issues_id.present?
    con.join(" OR ")
  end

  # Default is the manager or the majordomo of the dept
  def umpirage_approver
    i = 1
    begin
      case i
        when 1
          approval = Approval.umpirages.find_by("object_type = 'user' and object_id = ?", self.id)
          master = approval.user
        when 2
          all_up_depts = self.dept.all_up_levels(:id => true).join(",")
          approvals = Approval.umpirages.where("object_type = 'dept' and object_id IN (#{all_up_depts})").order("FIELD(object_id, #{all_up_depts})")
          approval = approvals.first
          master = approval.user
        when 3
          emp_id = [:manager_number, :manager2_number, :sub_manager_number, :sub_manager2_number, :majordomo_number].map{|attr| self.dept.send(attr)}.select{|id| id.to_i > 0}.first
          emp_id = 'cenx' if emp_id.blank?
          master = User.find_by(empId: emp_id)
        when 4
          master = User.where(:admin => true).third
      end
      raise Errors::NotFound if master.nil?
    rescue
      i += 1
      retry
    end
    master
  end

  # 申请裁决状态根据指派者的上级决定发送邮件及系统通知给上级
  def find_umpirage_approver
    master_user = Approval.umpirages.find_by("object_type = 'user' and object_id = ?", self.id)
    dept_id = self.try(:dept).try(:id)
    parent_dept_id = self.try(:dept).try(:parent).try(:id)

    
    @master_dept = Approval.umpirages.where("object_type = 'dept' and object_id = ? ", dept_id) if dept_id.present?
    @master_dept = Approval.umpirages.where("object_type = 'dept' and object_id = ? ", parent_dept_id) if @master_dept.blank? && parent_dept_id.present?
    @master_dept = nil if @master_dept.blank? && dept_id.blank? && parent_dept_id.blank?

    master = []
    if master_user.present?
      master << master_user.user
    elsif @master_dept.present?
      master = @master_dept.map(&:user)
    elsif group_bmjl_empId.present? && group_bmjl_empId != 0
      master << User.find_by(empId: group_bmjl_empId)
    elsif group_zongjian_empId.present? && group_zongjian_empId != 0
      master << User.find_by(empId: group_zongjian_empId)
    else
      master = []
    end

    return master, master.map(&:id)
  end

  # Undisposed bug, except S4 and closed project's
  def undisposed_over(days)
    return [] if days.blank?
    demand_id = IssuePriority.demand.present?? IssuePriority.demand.id : 0
    issues = Issue.on_active_project.where("tracker_id = 1 AND by_tester = 1 AND priority_id <> #{demand_id} AND status_id IN (#{IssueStatus::LEAVE_STATUS}) AND assigned_to_id = #{self.id}")
    issues.map do |issue|
      details = JournalDetail.select("journal_details.*, journals.user_id, journals.created_on")
                             .joins(journal: :issue)
                             .where("issues.id = ?", issue.id)
                             .order("journals.created_on DESC")
                             .to_a
      lastest_record = details.select{ |d| d.prop_key == "assigned_to_id" }.first # Last assigned date
      lastest_record ||= details.select{ |d| d.prop_key == "status_id" }.first  # Last status change date
      if lastest_record.present?
        lastest_edit = issue.journals.where("user_id = ? AND created_on > ?", self.id, lastest_record.created_on).order(created_on: :desc).first
        since_date = (lastest_edit || lastest_record).created_on
        days.map do |day|
          undisposed_day = (Date.today - since_date.to_date).to_i
          nextday = days[days.index(day) + 1]
          if nextday.present? # Not last element
            undisposed_day >= day && undisposed_day < nextday ? issue.id : nil
          else
            undisposed_day >= day ? issue.id : nil
          end
        end
      end
    end.compact.transpose
  end


  def dept_name(options = {})
    defaults = {:level => 2}
    options = defaults.merge(options)
    level = options[:level]
    dept = self.dept
    dept_name = [dept.try(:orgNm)]
    (level - 1).times do
      dept = dept.try(:parent)
      dept_name << dept.try(:orgNm) if dept.present?
    end
    dept_name.reverse.join("/")
  end

  def to_pinyin
    PinYin.of_string(self.firstname).join("_").camelize
  end

  def permissions
    permis = $redis.fetch(:hget, "global/users_permissions", id) do |opt|
      permi = (resourcing.try(:permissions) || []).to_json
      $redis.hset *opt, permi
      permi
    end

    (JSON.load permis).map(&:to_sym)
  end

  def has_permission?(permission)
    name = permission.is_a?(String) ? permission.to_sym : permission.name
    permissions.present? && permissions.include?(name)
  end

  def resourcing_permission?(permission)
    login? && resourcing.present? && resourcing.permissions.include?(permission)
  end

  def notices
    notice_tabs = {}
    user = User.current
    @tasks = user.tasks

    @personal_tasks = @tasks.where("container_type = 'PersonalTask' AND author_id <> assigned_to_id AND is_read = 0").count
    @issue_to_result_tasks = @tasks.where("container_type = 'IssueToSpecialTestResult' AND is_read = 0").count
    @issue_to_merge_tasks = @tasks.where("container_type = 'IssueToMerge' AND is_read = 0").count
    @issue_to_approve_tasks = @tasks.where("container_type = 'IssueToApprove' AND is_read = 0").count
    @apk_base_tasks = @tasks.where("container_type = 'ApkBase' AND status = 24").count
    @patch_version_tasks = @tasks.joins("INNER JOIN patch_versions pv ON pv.id = tasks.container_id AND tasks.container_type = 'PatchVersion' AND (pv.result IS NULL OR pv.result = 'NG')").count
    @library_update_tasks =  @tasks.where(container_type: "Library", status: 18).count.to_i+ @tasks.joins("INNER JOIN library_files lf ON lf.id = tasks.container_id AND tasks.container_type = 'LibraryFile' AND lf.status = 'failed'").count.to_i
    @library_merge_tasks = @tasks.where(container_type: "Library", status: [20, 22]).count.to_i

    notice_tabs[:items] = {}
    if @personal_tasks > 0
      notice_tabs[:items][:personal_task] = {name: "我的个人任务", url: "/my/tasks?type=personal_task&person_type=assigned_to_id", count: @personal_tasks}
    end

    if @issue_to_result_tasks > 0
      notice_tabs[:items][:issue_to_special_test_result] = {name: "我的专项测试任务", url: "/my/tasks?type=issue_to_special_test_task", count: @issue_to_result_tasks}
    end

    if @issue_to_merge_tasks > 0
      notice_tabs[:items][:issue_to_merge] = {name: "我的合入问题任务", url: "/my/tasks?type=issue_to_merge_task", count: @issue_to_merge_tasks}
    end

    if @issue_to_approve_tasks > 0
      notice_tabs[:items][:issue_to_approve] = {name: "我的必合问题任务", url: "/my/tasks?type=issue_to_approve_task", count: @issue_to_approve_tasks}
    end

    if @apk_base_tasks > 0
      notice_tabs[:items][:apk_base] = {name: "APK信息评审", url: "/my/tasks?type=apk_base_task", count: @apk_base_tasks}
    end

    if @patch_version_tasks > 0
      notice_tabs[:items][:patch_version] = {name: "版本验证任务", url: "/my/tasks?type=patch_version_task", count: @patch_version_tasks}
    end

    if @library_update_tasks > 0
      notice_tabs[:items][:library_update] = {name: "分支升级任务", url: "/my/tasks?type=library_update_task", count: @library_update_tasks} 
    end

    if @library_merge_tasks > 0
      notice_tabs[:items][:library_merge] = {name: "合入推送任务", url: "/my/tasks?type=library_merge_task", count: @library_merge_tasks}
    end

    commit_status = IssueStatus::COMMIT_STATUS
    @submitted_issue = Issue.select("id, status_id, tfde_id").where(status_id: commit_status, tfde_id: user.id).length
    if @submitted_issue > 0
      notice_tabs[:items][101] = {:name => "#{'&nbsp;'*4}提交", :url => "/issues?search=issues.tfde_id=#{user.id}+and+issues.status_id+in+(#{commit_status})", :count => @submitted_issue}
    end

    doubt_status = IssueStatus::DOUBT_STATUS
    @doubt_issue = Issue.select("id, status_id, assigned_to_id").where(status_id: doubt_status, assigned_to_id: user.id).length
    if @doubt_issue > 0
      notice_tabs[:items][102] = {:name => "#{'&nbsp;'*4}无法理解", :url => "/issues?search=issues.assigned_to_id=#{user.id}+and+issues.status_id+in+(#{doubt_status})", :count => @doubt_issue}
    end

    assigned_status = IssueStatus::ASSIGNED_STATUS
    @assigned_issue = Issue.select("id, status_id, assigned_to_id").where(status_id: assigned_status, assigned_to_id: user.id).length
    if @assigned_issue > 0
      notice_tabs[:items][103] = {:name => "#{'&nbsp;'*4}分配", :url => "/issues?search=issues.assigned_to_id=#{user.id}+and+issues.status_id+in+(#{assigned_status})", :count => @assigned_issue}
    end

    reassigned_status = IssueStatus::REASSIGNED_STATUS
    @reassigned_issue = Issue.select("id, status_id, assigned_to_id").where(status_id: reassigned_status, assigned_to_id: user.id).length
    if @reassigned_issue > 0
      notice_tabs[:items][104] = {:name => "#{'&nbsp;'*4}重分配", :url => "/issues?search=issues.assigned_to_id=#{user.id}+and+issues.status_id+in+(#{reassigned_status})", :count => @reassigned_issue}
    end

    open_status = IssueStatus::OPEN_STATUS
    @open_issue = Issue.select("id, status_id, assigned_to_id").where(status_id: open_status, assigned_to_id: user.id).length
    if @open_issue > 0
      notice_tabs[:items][105] = {:name => "#{'&nbsp;'*4}打开", :url => "/issues?search=issues.assigned_to_id=#{user.id}+and+issues.status_id+in+(#{open_status})", :count => @open_issue}
    end

    reopen_status = IssueStatus::REOPEN_STATUS
    @reopen_issue = Issue.select("id, status_id, assigned_to_id").where(status_id: reopen_status, assigned_to_id: user.id).length
    if @reopen_issue > 0
      notice_tabs[:items][106] = {:name => "#{'&nbsp;'*4}重打开", :url => "/issues?search=issues.assigned_to_id=#{user.id}+and+issues.status_id+in+(#{reopen_status})", :count => @reopen_issue}
    end

    analysis_status = IssueStatus::ANALYSIS_STATUS
    @analysis_issue = Issue.select("id, status_id, assigned_to_id").where(status_id: analysis_status, assigned_to_id: user.id).length
    if @analysis_issue > 0
      notice_tabs[:items][107] = {:name => "#{'&nbsp;'*4}三方分析", :url => "/issues?search=issues.assigned_to_id=#{user.id}+and+issues.status_id+in+(#{analysis_status})", :count => @analysis_issue}
    end

    repeat_status = IssueStatus::REPEAT_STATUS
    @repeat_issue = Issue.select("id, status_id, author_id").where(status_id: repeat_status, author_id: user.id).length
    if @repeat_issue > 0
      notice_tabs[:items][108] = {:name => "#{'&nbsp;'*4}重复", :url => "/issues?search=issues.author_id=#{user.id}+and+issues.status_id+in+(#{repeat_status})", :count => @repeat_issue}
    end

    refuse_status = IssueStatus::REFUSE_STATUS
    @refuse_issue = Issue.select("id, status_id, author_id").where(status_id: refuse_status, author_id: user.id).length
    if @refuse_issue > 0
      notice_tabs[:items][109] = {:name => "#{'&nbsp;'*4}拒绝", :url => "/issues?search=issues.author_id=#{user.id}+and+issues.status_id+in+(#{refuse_status})", :count => @refuse_issue}
    end

    appy_umpirage_status = IssueStatus::APPY_UMPIRAGE_STATUS
    @appy_umpirage_condition = condition_of_all_umpirage_apply
    if @appy_umpirage_condition.present?
      @cond = "(#{@appy_umpirage_condition.to_s}) AND issues.status_id = #{appy_umpirage_status}"
      @query = IssueQuery.new(:name => "_")
      @query.filters = {:condition => @cond}
      @appy_umpirage_issue = @query.issue_count
      if @appy_umpirage_issue > 0
        notice_tabs[:items][110] = {:name => "#{'&nbsp;'*4}申请裁决", :url => "/issues?search=%28#{CGI::escape @appy_umpirage_condition}%29+and+issues.status_id=#{appy_umpirage_status}", :count => @appy_umpirage_issue}
      end
    end

    @umpirage_issue = Issue.select("id, status_id, umpire_id").caijue.length
    if @umpirage_issue > 0
      notice_tabs[:items][111] = {:name => "#{'&nbsp;'*4}裁决", :url => '/issues?caijue=me', :count => @umpirage_issue}
    end

    if user.can_do?("judge", "project_branch")
      @apply_proj_count = RepoRequest.where(category: 1, status: 1).count
      if @apply_proj_count > 0
        notice_tabs[:items][:z_apply_proj] = {:name => "项目分支评审", :url => "/project_branch/repo_requests", :count => @apply_proj_count }
      end
    end

    if user.can_do?("judge", "production_repo")
      @apply_prod_count = RepoRequest.where(category: 3, status: 1).count
      if @apply_prod_count > 0
        notice_tabs[:items][:z_apply_prod] = {:name => "产品建仓确认", :url => "/production_repo/repo_requests", :count => @apply_prod_count }
      end
    end

    @confirm_proj_count = RepoRequest.software_records.count
    if @confirm_proj_count > 0
      notice_tabs[:items][:z_confirm_proj] = {:name => "项目分支信息录入", :url => "/project_branch/repo_requests", :count => @confirm_proj_count }
    end
    
    @task_total = @personal_tasks + @issue_to_result_tasks + @issue_to_merge_tasks + @issue_to_approve_tasks + @apk_base_tasks + @patch_version_tasks + @library_update_tasks + @library_merge_tasks
    @issue_total = @submitted_issue + @doubt_issue + @assigned_issue + @reassigned_issue + @open_issue + @reopen_issue + @analysis_issue + @repeat_issue + @refuse_issue + @appy_umpirage_issue.to_i + @umpirage_issue
    @repo_request_total = @apply_proj_count.to_i + @apply_prod_count.to_i + @confirm_proj_count.to_i
    @total = @task_total + @issue_total + @repo_request_total

    if @issue_total > 0
      notice_tabs[:items][100] = {:name => "需要我处理的bug", :url => "javascript:void(0);", :count => @issue_total}
    end

    #TODO --- 是否可以在Hash某位置插入元素 ---
    notice_tabs[:items] = notice_tabs[:items].sort_by { |key, val| key.to_s }.to_h
    notice_tabs[:task_total] = @task_total
    notice_tabs[:issue_total] = @issue_total
    notice_tabs[:total_count] = @total

    return notice_tabs
  end

  def reset_password(pwd = DEFAULT_PASSWORD)
    if self.type == "User"
      self.update_attribute(:hashed_password, User.hash_password("#{salt}#{User.hash_password pwd}"))
    end
  end

  ###################

  protected

  def validate_password_length
    return if password.blank? && generate_password?
    # Password length validation based on setting
    if !password.nil? && password.size < Setting.password_min_length.to_i
      errors.add(:password, :too_short, :count => Setting.password_min_length.to_i)
    end
  end

  def instantiate_email_address
    email_address || build_email_address
  end

  def avatar_size
    if picture.size > 3.megabytes
      errors.add(:picture, "should be less than 1MB")
    end
  end

  private

  def generate_password_if_needed
    if generate_password? && auth_source.nil?
      length = [Setting.password_min_length.to_i + 2, 10].max
      random_password(length)
    end
  end

  # Delete all outstanding password reset tokens on password change.
  # Delete the autologin tokens on password change to prohibit session leakage.
  # This helps to keep the account secure in case the associated email account
  # was compromised.
  def destroy_tokens
    if hashed_password_changed? || (status_changed? && !active?)
      tokens = ['recovery', 'autologin', 'session']
      Token.where(:user_id => id, :action => tokens).delete_all
    end
  end

  # Removes references that are not handled by associations
  # Things that are not deleted are reassociated with the anonymous user
  def remove_references_before_destroy
    return if self.id.nil?

    substitute = User.anonymous
    Attachment.where(['author_id = ?', id]).update_all(['author_id = ?', substitute.id])
    Comment.where(['author_id = ?', id]).update_all(['author_id = ?', substitute.id])
    Issue.where(['author_id = ?', id]).update_all(['author_id = ?', substitute.id])
    Issue.where(['assigned_to_id = ?', id]).update_all('assigned_to_id = NULL')
    Journal.where(['user_id = ?', id]).update_all(['user_id = ?', substitute.id])
    JournalDetail.
      where(["property = 'attr' AND prop_key = 'assigned_to_id' AND old_value = ?", id.to_s]).
      update_all(['old_value = ?', substitute.id.to_s])
    JournalDetail.
      where(["property = 'attr' AND prop_key = 'assigned_to_id' AND value = ?", id.to_s]).
      update_all(['value = ?', substitute.id.to_s])
    Message.where(['author_id = ?', id]).update_all(['author_id = ?', substitute.id])
    News.where(['author_id = ?', id]).update_all(['author_id = ?', substitute.id])
    # Remove private queries and keep public ones
    ::Query.delete_all ['user_id = ? AND visibility = ?', id, ::Query::VISIBILITY_PRIVATE]
    ::Query.where(['user_id = ?', id]).update_all(['user_id = ?', substitute.id])
    TimeEntry.where(['user_id = ?', id]).update_all(['user_id = ?', substitute.id])
    Token.delete_all ['user_id = ?', id]
    Watcher.delete_all ['user_id = ?', id]
    WikiContent.where(['author_id = ?', id]).update_all(['author_id = ?', substitute.id])
    WikiContent::Version.where(['author_id = ?', id]).update_all(['author_id = ?', substitute.id])
  end

  # Return password digest
  def self.hash_password(clear_password)
    Digest::SHA1.hexdigest(clear_password || "")
  end

  # Returns a 128bits random salt as a hex string (32 chars long)
  def self.generate_salt
    Redmine::Utils.random_hex(16)
  end

  # Send a security notification to all admins if the user has gained/lost admin privileges
  def deliver_security_notification
    options = {
      field: :field_admin,
      value: login,
      title: :label_user_plural,
      url: {controller: 'users', action: 'index'}
    }

    deliver = false
    if (admin? && id_changed? && active?) ||    # newly created admin
       (admin? && admin_changed? && active?) || # regular user became admin
       (admin? && status_changed? && active?)   # locked admin became active again

       deliver = true
       options[:message] = :mail_body_security_notification_add

    elsif (admin? && destroyed? && active?) ||      # active admin user was deleted
          (!admin? && admin_changed? && active?) || # admin is no longer admin
          (admin? && status_changed? && !active?)   # admin was locked

          deliver = true
          options[:message] = :mail_body_security_notification_remove
    end

    if deliver
      users = User.active.where(admin: true).to_a
      Mailer.security_notification(users, options).deliver
    end
  end
end

class AnonymousUser < User
  validate :validate_anonymous_uniqueness, :on => :create

  self.valid_statuses = [STATUS_ANONYMOUS]

  def validate_anonymous_uniqueness
    # There should be only one AnonymousUser in the database
    errors.add :base, 'An anonymous user already exists.' if AnonymousUser.exists?
  end

  def available_custom_fields
    []
  end

  # Overrides a few properties
  def logged?; false end
  def admin; false end
  def name(*args); I18n.t(:label_user_anonymous) end
  def mail=(*args); nil end
  def mail; nil end
  def time_zone; nil end
  def rss_key; nil end

  def pref
    UserPreference.new(:user => self)
  end

  # Returns the user's bult-in role
  def builtin_role
    @builtin_role ||= Role.anonymous
  end

  def membership(*args)
    nil
  end

  def member_of?(*args)
    false
  end

  # Anonymous user can not be destroyed
  def destroy
    false
  end

  protected

  def instantiate_email_address
  end
end

