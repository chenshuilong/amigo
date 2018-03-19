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


class Version < ActiveRecord::Base
  include Redmine::SafeAttributes
  require 'zip'

  serialize :mail_receivers, Array
  serialize :auto_test_projects, Array
  serialize :system_space, Hash
  serialize :special_app_versions, Hash
  serialize :version_yaml, Hash

  after_update :update_issues_from_sharing_change, :send_version_compiled_notification
  before_save :set_parent_id, :update_increase_versions, :set_last_successful_version, :change_name_if_ci
  before_destroy :nullify_projects_default_version

  belongs_to :project
  belongs_to :spec
  has_many :fixed_issues, :class_name => 'Issue', :foreign_key => 'fixed_version_id', :dependent => :nullify
  has_many :releases, :class_name => 'VersionRelease'
  has_many :issues, :class_name => 'VersionIssue'
  has_many :app_lists, :class_name => 'VersionApplist'
  has_many :version_publishes, :class_name => "VersionPublish", foreign_key:"version_id"

  has_many :children, :class_name => 'Version', :foreign_key => 'parent_id'
  belongs_to :last_version, class_name: "Version", foreign_key: "last_version_id"
  belongs_to :repo_one, class_name: "Repo"
  belongs_to :repo_two, class_name: "Repo"
  belongs_to :author, :class_name => 'User'
  belongs_to :stopped_user, :class_name => 'User'
  belongs_to :parent, :class_name => 'Version', :foreign_key => 'parent_id'
  acts_as_customizable
  acts_as_attachable :view_permission => :view_files,
                     :edit_permission => :manage_files,
                     :delete_permission => :manage_files

  # VERSION_STATUSES = %w(open locked closed)
  VERSION_SHARINGS = %w(none descendants hierarchy tree system)

  VERSION_STATUS = {:planning => 1, :testing => 2, :reserved => 3, :released => 4, :abandoned => 5, :deleted => 6, :google_approved => 7}.freeze
  VERSION_PRIORITY = {:high => 1, :middle => 2, :normal => 3, :low => 4}
  VERSION_COMPILE_STATUS = {:submitted => 1, :queued => 2, :pending_compiling => 3, :compiling => 4, :failed => 5, :successful => 6, :stopped => 7}
  VERSION_COMPILE_TYPE = {:user => 1, :eng => 2, :userdebug => 3}
  VERSION_ARM = [32, 64]
  # VERSION_SONAR_TEST = {:no => 1, :incremental => 2, :publish => 3}

  validates :name, :status, :priority, :spec_id, :repo_one_id, presence: true
  validates :repo_two_id, :arm, presence: true, :if => "project.show_by(4) && project.production_type == 1"
  validates :sendtest_at, presence: true, :if => "status == 7"

  # Check name for apk
  validates :name,
            :format => {:with => /\AV\d+.\d+.\d+.[a-z]+\z/},
            :uniqueness => {scope: [:project_id, :spec_id], :message => :version_app_name_already_exists},
            :if => "project.show_by(4) && (project.production_type == 1)"

  # Check name for modem
  validates :name,
            :format => {:with => /\AT\d+\z/},
            :uniqueness => {scope: [:project_id, :spec_id], :message => :version_app_name_already_exists},
            :if => "project.show_by(4) && project.production_type == 2"

  # Check name for framework
  validates :name,
            :format => {:with => /\AV\d+.\d+.\d+.[a-z0-9]+\z/},
            :uniqueness => {scope: [:project_id, :spec_id], :message => :version_app_name_already_exists},
            :if => "project.show_by(4) && project.production_type == 3"

  # Check name for preload
  validates :name,
            :format => {:with => /\AV\d+\z/},
            :uniqueness => {scope: [:project_id, :spec_id], :message => :version_app_name_already_exists},
            :if => "project.show_by(4) && project.production_type == 4"

  # Check name for project 1,2,3
  validates :name,
            :format => {:with => /\AT\d+\z/},
            :uniqueness => {scope: [:project_id, :spec_id], :message => :already_exists},
            :if => "project.show_by(1,2,3)"

  validates_length_of :name, :maximum => 60
  # validates_length_of :description, :maximum => 255
  validates :effective_date, :date => true
  validates :status, inclusion: {in: VERSION_STATUS.values}
  # validates_inclusion_of :sharing, :in => VERSION_SHARINGS
  validate :check_project_version_name_uniq

  attr_protected :id


  scope :named, lambda { |arg| where("LOWER(#{table_name}.name) = LOWER(?)", arg.to_s.strip) }
  scope :like, lambda { |arg| where("LOWER(#{table_name}.name) LIKE '%#{arg.to_s.strip}%'")}
  scope :open, lambda { where(:status => VERSION_STATUS.slice(:planning, :reserved, :testing, :released).values) }
  scope :visible, lambda { |*args|
    joins(:project).
        where(Project.allowed_to_condition(args.first || User.current, :view_issues))
  }
  scope :compile_status, lambda { |arg| where(arg.blank? ? nil : {:compile_status => arg}) }
  scope :main_versions, -> { where(:parent_id => nil).reorder(spec_id: :asc, name: :asc) }
  # scope :releasable, -> { includes(:releases).where("versions.compile_status = 6") }
  scope :releasable, -> (release_category = nil) {
    versions = includes(:releases).where("versions.compile_status = 6")
    case release_category
    when :bugfix
      versions.references(:releases).where("version_releases.id IS NULL OR version_releases.category <> 3")
    when :adapt # KEEP!
      versions
    when :complete
      no_ids = VersionRelease.joins(:version)
                             .where('version_releases.category = 1 AND version_releases.status <> 9')
                             .pluck('version_releases.version_id, versions.parent_id')
                             .transpose.map{|idd| idd.compact.uniq.join(',')}
      versions.where("versions.id NOT IN (#{no_ids.join(',')}) AND versions.parent_id NOT IN (#{no_ids.last})")
    else
      versions
    end
  }

  scope :success_versions, -> { where(:compile_status => VERSION_COMPILE_STATUS[:successful]).reorder(spec_id: :asc, name: :asc) }
  scope :success_child_version, lambda {|project_id, parent_id| success_versions.joins("inner join version_releases on versions.id = version_releases.version_id and version_releases.status = 5")
                                                                    .where(:project_id => project_id, :parent_id => parent_id).reorder(compile_end_on: :desc) }
  scope :released_version, lambda { |version_id| joins("inner join version_releases on versions.id = version_releases.version_id and version_releases.status = 5").where("versions.id = #{version_id}") }
  scope :project_category, lambda { |arg|
    joins(:project).where(projects: {:category => arg == 'other' ? [4] : [1, 2, 3]})
  }
  # Select spec_list and version_list for spec/version choose
  scope :compare_choose, lambda { |sql|
    joins("inner join specs on specs.id = versions.spec_id and specs.deleted = false")
    .select("GROUP_CONCAT( DISTINCT CONCAT_WS(',', CONCAT(specs.name, '_', replace(versions.name, CONCAT('.',SUBSTRING_INDEX(versions.name,'.',-1)), ''))) order by specs.name, versions.name SEPARATOR ',' ) as spec_list,
            GROUP_CONCAT(CONCAT_WS(',', versions.name, versions.id) SEPARATOR ',') as version_list")
    .where(sql)
    .group("spec_id").reorder("spec_list")
  }
  scope :terminal_versions, lambda{
    success_versions
    .joins("INNER JOIN projects ON projects.id = versions.project_id AND projects.category <> 4
           INNER JOIN specs ON specs.id = versions.spec_id")
    .select("versions.id, CONCAT(projects.identifier, '_',specs.name, '_',versions.name) AS name, version_yaml")
  }

  safe_attributes 'name',
                  'description',
                  'effective_date',
                  'due_date',
                  'wiki_page_title',
                  'status',
                  'sharing',
                  'production_name',
                  'baseline',
                  'label',
                  'path',
                  'custom_field_values',
                  'custom_fields',
                  'repo_one_id',
                  'repo_two_id',
                  'spec_id',
                  'priority',
                  'compile_type',
                  'ota_whole_compile',
                  'ota_increase_compile',
                  'ota_increase_versions',
                  'as_increase_version',
                  'continue_integration',
                  'signature',
                  'arm',
                  'strengthen',
                  'auto_test',
                  'unit_test',
                  'auto_test_projects',
                  'sonar_test',
                  'compile_due_on',
                  'mail_receivers',
                  'coverity',
                  'timezone',
                  'gradle_version',
                  'system_space',
                  'sendtest_at'

  # Returns true if +user+ or current user is allowed to view the version
  def visible?(user=User.current)
    user.allowed_to?(:view_issues, self.project)
  end

  # Version files have same visibility as project files
  def attachments_visible?(*args)
    project.present? && project.attachments_visible?(*args)
  end

  def attachments_deletable?(usr=User.current)
    project.present? && project.attachments_deletable?(usr)
  end

  def start_date
    @start_date ||= fixed_issues.minimum('start_date')
  end

  def due_date
    effective_date
  end

  def due_date=(arg)
    self.effective_date=(arg)
  end

  # Returns the total estimated time for this version
  # (sum of leaves estimated_hours)
  def estimated_hours
    @estimated_hours ||= fixed_issues.sum(:estimated_hours).to_f
  end

  # Returns the total reported time for this version
  def spent_hours
    @spent_hours ||= TimeEntry.joins(:issue).where("#{Issue.table_name}.fixed_version_id = ?", id).sum(:hours).to_f
  end

  def closed?
    VERSION_STATUS.slice(:abandoned, :deleted).value? status
  end

  def open?
    VERSION_STATUS.slice(:planning, :reserved, :testing, :released).value? status
  end

  # Returns true if the version is completed: closed or due date reached and no open issues
  def completed?
    closed? || (effective_date && (effective_date < User.current.today) && (open_issues_count == 0))
  end

  def behind_schedule?
    if completed_percent == 100
      return false
    elsif due_date && start_date
      done_date = start_date + ((due_date - start_date+1)* completed_percent/100).floor
      return done_date <= User.current.today
    else
      false # No issues so it's not late
    end
  end

  # Returns the completion percentage of this version based on the amount of open/closed issues
  # and the time spent on the open issues.
  def completed_percent
    if issues_count == 0
      0
    elsif open_issues_count == 0
      100
    else
      issues_progress(false) + issues_progress(true)
    end
  end

  # Returns the percentage of issues that have been marked as 'closed'.
  def closed_percent
    if issues_count == 0
      0
    else
      issues_progress(false)
    end
  end

  # Returns true if the version is overdue: due date reached and some open issues
  def overdue?
    effective_date && (effective_date < User.current.today) && (open_issues_count > 0)
  end

  # Returns assigned issues count
  def issues_count
    load_issue_counts
    @issue_count
  end

  # Returns the total amount of open issues for this version.
  def open_issues_count
    load_issue_counts
    @open_issues_count
  end

  # Returns the total amount of closed issues for this version.
  def closed_issues_count
    load_issue_counts
    @closed_issues_count
  end

  def wiki_page
    if project.wiki && !wiki_page_title.blank?
      @wiki_page ||= project.wiki.find_page(wiki_page_title)
    end
    @wiki_page
  end

  def to_s;
    name
  end

  def to_s_with_project
    "#{project} - #{name}"
  end

  # Versions are sorted by effective_date and name
  # Those with no effective_date are at the end, sorted by name
  def <=>(version)
    if self.effective_date
      if version.effective_date
        if self.effective_date == version.effective_date
          name == version.name ? id <=> version.id : name <=> version.name
        else
          self.effective_date <=> version.effective_date
        end
      else
        -1
      end
    else
      if version.effective_date
        1
      else
        name == version.name ? id <=> version.id : name <=> version.name
      end
    end
  end

  def css_classes
    [
        completed? ? 'version-completed' : 'version-incompleted',
        "version-#{status}"
    ].join(' ')
  end

  def self.fields_for_order_statement(table=nil)
    table ||= table_name
    ["(CASE WHEN #{table}.effective_date IS NULL THEN 1 ELSE 0 END)", "#{table}.effective_date", "#{table}.name", "#{table}.id"]
  end

  def self.check_if_time_to_compile
    where('compile_due_on <= ? AND compile_status = ?', Time.now, VERSION_COMPILE_STATUS[:submitted]).update_all(
        :compile_status => VERSION_COMPILE_STATUS[:queued]
    )
  end

  # type: :project, :app, :modem, :framework
  def self.find_by_fullname(fullname)
    return if fullname.nil?

    type  = parse_project_type fullname
    scope = Version.select("#{table_name}.id,#{table_name}.name,#{table_name}.project_id").joins(:project, :spec).where(:specs => {:deleted => false})
    case type
      when :app
        version_name = fullname.match(/V\d+\.\d+\.\d+\.\w+\z/)[0]
        project_spec_name = fullname.gsub("_#{version_name}", '')
        scope.where("versions.name = ? AND CONCAT(projects.identifier,'_',specs.name) = ?
                     AND projects.production_type = 1", version_name, project_spec_name)
      when :modem
        version_name = fullname.match(/T\d+\z/)[0]
        project_spec_name = fullname.gsub("_#{version_name}", '')
        scope.where("versions.name = ? AND CONCAT(SUBSTRING(projects.identifier,1,7),specs.name,'_MODEM') = ?
                     AND projects.production_type = 2", version_name, project_spec_name)
      when :framework
        version_name = fullname.match(/V\d+\.\d+\.\d+\.\w+\z/)[0]
        project_spec_name = fullname.gsub("_#{version_name}", '')
        scope.where("versions.name = ? AND CONCAT(projects.identifier,'_',specs.name) = ?
                     AND projects.production_type = 3", version_name, project_spec_name)
      when :preload
        version_name = fullname.match(/V\d+\w+\z/)[0]
        project_spec_name = fullname.gsub("_#{version_name}", '')
        scope.where("versions.name = ? AND CONCAT(projects.identifier,'_',specs.name) = ?
                     AND projects.production_type = 4", version_name, project_spec_name)
      else # :project
        version_name = fullname.match(/T\d+\z/)[0]
        project_spec_name = fullname.gsub("_#{version_name}", '')
        scope.where("versions.name = ? AND CONCAT(SUBSTRING_INDEX(projects.identifier,'_',1),specs.name) = ?
                     AND projects.category <> 4", version_name, project_spec_name)
    end.first
  end

  def self.parse_project_type(fullname)
    case fullname
      when /_MODEM_T\d+\z/i then :modem
      when /\AAmigo_Framework/i then :framework
      when /V\d+\.\d+\.\d+\.\w+\z/ then :app
      when /V\d+\z/ then :preload
      else :project
    end
  end

  scope :sorted, lambda { order(fields_for_order_statement) }

  # Returns the sharings that +user+ can set the version to
  def allowed_sharings(user = User.current)
    VERSION_SHARINGS.select do |s|
      if sharing == s
        true
      else
        case s
          when 'system'
            # Only admin users can set a systemwide sharing
            user.admin?
          when 'hierarchy', 'tree'
            # Only users allowed to manage versions of the root project can
            # set sharing to hierarchy or tree
            project.nil? || user.allowed_to?(:manage_versions, project.root)
          else
            true
        end
      end
    end
  end

  # Returns true if the version is shared, otherwise false
  def shared?
    sharing != 'none'
  end

  def deletable?
    false
    # fixed_issues.empty? && !referenced_by_a_custom_field?
  end

  def compile_total_hours
    if compile_start_on && compile_end_on
      diff = compile_end_on - compile_start_on
      if diff >= 1.hours
        l(:version_compile_total_hours,
          :hours => (diff / 1.hours).round(1))
      else
        l(:version_compile_total_minutes,
          :minutes => (diff / 1.minutes).round)
      end
    end
  end

  def find_increase_versions(api = false)
    versions = Version.where(:id => ota_increase_version_ids)
    unless api
      versions.present? ? versions.pluck(:name).join(", ") : "-"
    else
      versions.present? ? "#{production_list}:#{versions.pluck(:name).join(';')}" : ""
    end
  end

  # Fetch all increase version before creating, range like eg: WBL17G01A_1701/WBL17G01A/WBL17G01A_autotest
  def current_increase_versions
    project_ids = Project.where("identifier LIKE '#{project.identifier.split('_').first}%'").pluck(:id)
    Version.joins(:spec).where(versions: {project_id: project_ids}, specs: {name: spec.name}, as_increase_version: true)
  end

  def all_increase_versions
    project_ids = Project.where("identifier LIKE '#{project.identifier.split('_').first}%'").pluck(:id)
    Version.joins(:spec).where(versions: {project_id: project_ids}, as_increase_version: true)
  end

  def ota_increase_version_ids
    ota_increase_versions.try(:split, ",")
  end

  # Provide free editing before version to be compling
  def free_edit?
    !compile_status || VERSION_COMPILE_STATUS.slice(:submitted, :queued).value?(compile_status)
  end

  def compiled_successfully?
    compile_status == VERSION_COMPILE_STATUS[:successful] && status != VERSION_STATUS[:deleted]
  end

  def prefix
    if project.show_by(4)
      (ver = name.gsub(/\.[a-z]+\z/i, '')).present? ? (ver.split('.').count == 4 ? ver.split('.')[0..-2].join('.') : ver) : ver
    end
  end

  def fullname
    if project.show_by(4) # APP
      if project.production_type == 2 # Modem
        [project.identifier.split("_").first.upcase + spec.name, 'MODEM', name].join('_')
      else
        [project.identifier, spec.name, name].join('_')
      end
    else
      production_list + '_' + name
    end
  end

  def production_list
    if !project.show_by(4) || project.production_type == 2 # Modem
      project.identifier.split("_").first.upcase + spec.name
    end
  end

  def update_stopped_compile
    update_attributes(
        :compile_status => VERSION_COMPILE_STATUS[:stopped],
        :compile_stop_on => Time.now,
        :compile_end_on => Time.now,
        :stopped_user_id => User.current.try(:id)
    )
  end

  def is_compiling?
    compile_status == VERSION_COMPILE_STATUS[:compiling]
  end

  def is_stopped?
    compile_status == VERSION_COMPILE_STATUS[:stopped]
  end

  def find_parent_id
    slice(:parent_id, :id).values.compact.first
  end

  def utr_final_directory
    time = created_on || DateTime.now
    Rails.root.join('files', "#{time.strftime("%Y/%m")}/unit_test_reports/#{id}")
  end

  # utr_file is unit test report file
  def save_utr_file(incoming_file)
    if incoming_file
      logger.info("Saving Unit Test Report of version: #{to_s_with_project}(id = #{id})")
      begin
        file_name = incoming_file.original_filename
        file_type = file_name.split('.').last
        new_name_file = Redmine::Utils.random_hex(16)
        new_file_name_with_type = "#{new_name_file}." + file_type
        # Temp directory
        temp_path = Rails.root.join('files', 'temp')
        FileUtils.mkdir_p(temp_path) unless File.directory?(temp_path)
        # Save to temp directory
        File.open(temp_path + new_file_name_with_type, "wb") do |f|
          if incoming_file.respond_to?(:read)
            buffer = ""
            while (buffer = incoming_file.read(8192))
              f.write(buffer)
            end
          else
            f.write(incoming_file)
          end
        end
        # Unzip file
        FileUtils.mkdir_p(utr_final_directory) unless File.directory?(utr_final_directory)
        Zip::File.open(temp_path + new_file_name_with_type) do |zip_file|
          zip_file.each do |f|
            f_path = File.join(utr_final_directory, f.name)
            FileUtils.mkdir_p(File.dirname(f_path))
            zip_file.extract(f, f_path) unless File.exist?(f_path)
          end
        end
        save_status = true
      rescue
        save_status = false
      end
    else
      save_status = false
    end
  end

  def save_fixed_issues(issues)
    issues = JSON.parse(issues)
    issues.each do |issue|
      begin
        issue.merge!({issue_id: issue['issue_id'].to_s[/\d+/]})
        fixed_issue = self.issues.new(issue)
        fixed_issue.save
      rescue
        next
      end
    end

    # update app_version value in mentioned issues
    self.issues.where(:issue_type => VersionIssue::ISSUE_TYPE_AMIGO).each do |vi|
      issue = vi.issue
      next unless issue.project_id == self.project_id # Check if the same project

      self_id = self.id
      app_version = project.show_by(4)
      if issue.app_version_id.blank? || issue.status.name == '打开'
        if app_version
          issue.app_version_id = self_id
          issue.integration_version_id = nil
        else
          issue.integration_version_id = self_id
        end
        issue.save
      end
    end

    return true
  end

  # Save an applist compiled by this version(from the spec applist of this version's project)
  def save_applist(params)
    yaml = params[:yaml]
    apks = params[:apks]

    @project = self.project
    invalid_apks = []
    all_apk_bases = ApkBase.all.map(&:name)

    if yaml.present? # for new style compiling
      spec_applist = YAML.load yaml
      apks_applist = JSON.load apks
      
      #Save yaml content to version_yaml
      self.update_columns(version_yaml: spec_applist)

      # yaml: version_id and apk_name relation, eg: 1 => ['apk_name.apk', 'apk2_name.apk']
      version_ids        = []
      version_id_to_apks = {}
      sa_versions = {}
      if spec_applist['apps'].present?
        spec_applist['apps'].each do |key, value|
          vname = value['v']
          vers = Version.find_by(:id => value['vid'])

          if vers.blank? || vname.exclude?(vers.name)
            vers = Version.find_by_fullname("#{key}_#{vname}")
          end

          if vers.present? && (names = vers.app_lists.pluck :apk_name).present?
            version_id_to_apks[vers.id] = names
            version_ids << vers.id
          end

          if key == "Amigo_Framework"
            sa_versions = sa_versions.merge({"#{key}": value})
          end
        end
      end
      
      #Save Amigo Framework version information to special_app_versions
      self.update_columns(special_app_versions: sa_versions) if sa_versions.present?

      # check if any apk missing in version_id_to_apks
      # TODO: output warning
      all_apks = apks_applist.map{|applist| applist['apk_name']}
      version_id_to_apks.each do |id, apks|
        version_id_to_apks[id] = (apks & all_apks) unless apks.all? { |apk| all_apks.include?(apk) }
      end

      # carding all apks relationship to version_id_to_apks
      no_version_id_apks = all_apks - version_id_to_apks.values.flatten
      version_id_to_apks[:noid] = no_version_id_apks

      # save all apks with version_id
      version_id_to_apks.each do |id, apks|
        apks.sort.each do |apk|
          begin
            invalid_apks << check_invalid_apk_base(apk, all_apk_bases)
            app_list_attributes = apks_applist.detect{|applist| applist['apk_name'] == apk}
            app_list = self.app_lists.new(app_list_attributes)
            app_list.app_version_id = id if id != :noid
            app_list.save
          rescue
            next
          end
        end
      end

      # update integration_version value in where app_version_id eql version_ids of issues
      project.issues.where(:app_version_id => version_ids).each do |issue|
        self_id = self.id
        if issue.integration_version_id.blank?
          issue.integration_version_id = self_id
          issue.save
        end
      end
    else # app compiling and old style compiling
      apks = JSON.load apks
      apks.sort_by{|apk| apk['apk_name']}.each do |apk|
        begin
          invalid_apks << check_invalid_apk_base(apk['apk_name'], all_apk_bases)
          app_list = self.app_lists.new(apk)
          app_list.save
        rescue
          next
        end
      end
    end
    if invalid_apks.present?
      uniq_invalid_apks = invalid_apks.uniq.delete_if{|a| a.blank?}
      send_invalid_apk_base_notification(uniq_invalid_apks) if invalid_apks.present?
      return true
    end
  end

  def check_invalid_apk_base(apk_name, all_apk_bases)
    if project.category.to_i == 4
      #Production
      production_apks = project.apk_bases.map(&:name)
      if production_apks.present? && project.production_type.to_i == 1
        unless apk_name.in?(production_apks)
          invalid_apk = apk_name
          unless apk_name.in?(all_apk_bases)
            ApkBase.transaction do 
              apk_base = ApkBase.create(name: apk_name, android_platform: 1, integrated: false, app_category: project.production_type, author_id: 1)
              project_apk = ProjectApk.create(project_id: project.id, apk_base_id: apk_base.id, author_id: 1)
            end
          end
        end
      end
    else
      #Project
      invalid_apk = apk_name unless apk_name.in?(all_apk_bases)
    end
    return invalid_apk
  end

  def send_invalid_apk_base_notification(invalid_apks)
    if invalid_apks.present?
      ###send_email
      options = {:version => self, :invalid_apks => invalid_apks, :project => project}
      receivers = [] 
      if project.category.to_i == 4
        # production's APP-SPM
        app_spm_user = project.users_of_role(27)
        receivers = app_spm_user.present? ? app_spm_user : [User.find_by_firstname("刘慧娟")]
      else
        receivers = [User.find_by_firstname("刘小杰"), User.find_by_firstname("韩保君"), "sw_prj_leader@gionee.com", "li_qian@gionee.com"]
      end

      begin
        Mailer.invalid_apk_base_notification(receivers, options).deliver
      rescue
        receivers.each do |receiver|
          begin
            Mailer.invalid_apk_base_notification(receiver, options).deliver
          rescue
            next
          end
        end
      end        
    end
  end

  def update_yaml(params)
    yaml = params[:yaml]

    if yaml.present? # for new style compiling
      spec_applist = YAML.load yaml
      
      #Save yaml content to version_yaml
      self.update_columns(version_yaml: spec_applist)

      sa_versions = {}
      spec_applist['apps'].each do |key, value|
        next unless key == "Amigo_Framework"
        sa_versions = sa_versions.merge({"#{key}": value})
      end
      
      #Save Amigo Framework version information to special_app_versions
      self.update_columns(special_app_versions: sa_versions) if sa_versions.present?
    end
  end

  def releasable_projects
    main_version_id = find_parent_id
    Project.joins(specs: :spec_versions)
           .joins(:repos).joins(:projects_repos)
           .where(:specs => {:freezed => false, :deleted => false})
           .where(:spec_versions => {:version_id => main_version_id, :freezed => false, :deleted => false})
           .where(:projects_repos => {:freezed => false})
           .where("(specs.for_new = 3 AND repos.url IS NOT NULL AND repos.category = 10) " +
                  "OR (specs.for_new IN (1,2) AND LENGTH(spec_versions.release_path) > 0)"
            ).uniq

  end

  def get_history_versions(version_obj, result = [], end_time)
    @version = self.last_version

    if @version.present?
      if @version == version_obj
        result << @version.id
        return result
      elsif end_time <= Time.now #timeout >= 10s 跳出遍历，版本无法比较
        result << false
        return result
      elsif result.include?(@version.id) # avoid deep level exception
        result << @version.id
        result << false
        return result
      else
        result << @version.id
        @version.get_history_versions(version_obj, result, end_time)
      end
    else
      result << false
      return result
    end
  end

  # get spec_version name
  def sv_name
    if project.show_by(4) # APP
      if project.production_type == 2 # Modem
        [spec.name, 'MODEM', name].join('_')
      else
        [spec.name, name].join('_')
      end
    else
      spec.name + '_' + name
    end
  end

  def self.system_space_compare(va, vb)
    ids = all.map(&:id)
    @first = all.find_by(id: va)
    @last  = all.find_by(id: vb)
    @system_spaces = {va => @first.system_space, vb => @last.system_space}
    dirs = @first.system_space.keys + @last.system_space.keys

    result = []
    dirs.uniq.each do |dir|
      system_space_hash = {}
      system_space_hash[:dir]  = dir
      ids.each do |id|
        key = id == va ? "va" : "vb"
        system_space_hash[key.to_sym] = @system_spaces[id][dir.to_s] || '-'
      end
      diff = system_space_hash[:va].to_i - system_space_hash[:vb].to_i
      system_space_hash[:diff] = diff
      result << system_space_hash
    end
    
    return result
  end

  def self.app_infos(apps)
    @versions = self.all
    @app_infos = {}
    apps.each do |app|
      @app_infos[app] = {}
      @versions.each do |version|
        current_yaml = version.version_yaml
        if current_yaml.present? && current_yaml["apps"].present?
          if current_yaml["apps"][app].present?
            @app_infos[app] = @app_infos[app].merge({"#{version.name}": current_yaml["apps"][app]["v"]})
          else
            @app_infos[app] = @app_infos[app].merge({"#{version.name}": '-'})
          end
        else
          @app_infos[app] = @app_infos[app].merge({"#{version.name}": '-'})
        end
      end
    end
    return @app_infos
  end

  def name_rules
    rules = VersionNameRule.select("id, #{VersionNameRule.table_name}.name, (CASE WHEN LENGTH(#{VersionNameRule.table_name}.range) > 0 THEN #{VersionNameRule.table_name}.range ELSE '#{l(:periodic_version_rule_range_timestamp)}' END) `range`").where(:android_platform => self.project.android_platform)
    rules = rules.where("#{VersionNameRule.table_name}.name not like '%量产版本%'") if User.current.is_platform_driver?(self.project)
    rules
  end

  ###################

  private

  def load_issue_counts
    unless @issue_count
      @open_issues_count = 0
      @closed_issues_count = 0
      fixed_issues.group(:status).count.each do |status, count|
        if status.is_closed?
          @closed_issues_count += count
        else
          @open_issues_count += count
        end
      end
      @issue_count = @open_issues_count + @closed_issues_count
    end
  end

  # Update the issue's fixed versions. Used if a version's sharing changes.
  def update_issues_from_sharing_change
    if sharing_changed?
      if VERSION_SHARINGS.index(sharing_was).nil? ||
          VERSION_SHARINGS.index(sharing).nil? ||
          VERSION_SHARINGS.index(sharing_was) > VERSION_SHARINGS.index(sharing)
        Issue.update_versions_from_sharing_change self
      end
    end
  end

  # Returns the average estimated time of assigned issues
  # or 1 if no issue has an estimated time
  # Used to weight unestimated issues in progress calculation
  def estimated_average
    if @estimated_average.nil?
      average = fixed_issues.average(:estimated_hours).to_f
      if average == 0
        average = 1
      end
      @estimated_average = average
    end
    @estimated_average
  end

  # Returns the total progress of open or closed issues.  The returned percentage takes into account
  # the amount of estimated time set for this version.
  #
  # Examples:
  # issues_progress(true)   => returns the progress percentage for open issues.
  # issues_progress(false)  => returns the progress percentage for closed issues.
  def issues_progress(open)
    @issues_progress ||= {}
    @issues_progress[open] ||= begin
      progress = 0
      if issues_count > 0
        ratio = open ? 'done_ratio' : 100

        done = fixed_issues.open(open).sum("COALESCE(estimated_hours, #{estimated_average}) * #{ratio}").to_f
        progress = done / (estimated_average * issues_count)
      end
      progress
    end
  end

  def referenced_by_a_custom_field?
    CustomValue.joins(:custom_field).
        where(:value => id.to_s, :custom_fields => {:field_format => 'version'}).any?
  end

  def nullify_projects_default_version
    Project.where(:default_version_id => id).update_all(:default_version_id => nil)
  end

  def set_parent_id
    if project.show_by(4) && (new_record? || name_changed?)
      all_main_versions = project.versions.main_versions
      parent_version = all_main_versions.where("id <> #{id.to_i} AND spec_id = #{spec_id} AND name LIKE '#{prefix}%'")
      self.parent = parent_version.present? ? parent_version.first : nil
    end
  end

  def set_last_successful_version
    return true unless free_edit?

    scope = spec.versions.where(:compile_status => VERSION_COMPILE_STATUS[:successful], :repo_one_id => repo_one_id).reorder(compile_end_on: :desc)
    last_version = continue_integration?? scope.where(:continue_integration => true).first : scope.first
    if last_version.nil?
      version_name = repo_one.url.split("/").last[/T\d+/i]
      last_version = project.homologic_versions.where(:versions => {:name => version_name}).first
    end

    self.last_version = last_version
  end

  def change_name_if_ci
    if free_edit? && continue_integration? && name[/\d+/].size == 14
      self.name =  name.gsub(/\AT2/, "T9")
    end
  end

  def check_project_version_name_uniq
    unless project.show_by(4)
      if project.android_platform.to_i == Project::PROJECT_ANDROID_PLATFORM["O平台"].to_i
        # exist_version = project.versions.where("LENGTH(versions.name)=5 AND versions.name = '#{name}'").where(:spec_id => spec_id)
      else
        ident = project.identifier.to(6)
        exist_version = Version.joins(:project).where("projects.id <> #{project.id} AND projects.identifier LIKE '#{ident}%' AND versions.name = '#{name}' AND projects.category <> 4")
      end
      if exist_version.present?
        errors.add(:name, l(:version_error_exist_same_version_name, :name => exist_version.first.fullname))
      end
    end
  end

  def update_increase_versions
    if free_edit?
      if ota_increase_compile
        versions = current_increase_versions
        if versions.blank?
          self.ota_increase_compile = false
          self.ota_increase_versions = nil
        else
          self.ota_increase_versions = versions.ids.join(",")
        end
      else
        self.ota_increase_versions = nil
      end
    end
  end

  # When Version is compiled successfully or faild, send an email to users
  def send_version_compiled_notification
    if compile_status_changed? && [5, 6].include?(compile_status)
      default_cc = if project.show_by(4)
                     Setting.notified_production_version_compiled.map { |role_id| project.users_of_role(role_id) }.flatten
                   else
                     Setting.notified_version_compiled.select{|mail| mail.include?('@')}
                   end
      cc = User.where(:id => mail_receivers)
      receivers = cc | [default_cc]
      # receivers = [User.find(1125)] # Test

      # Firstly, send to all
      begin
        Mailer.version_compiled_notification(receivers, :version => self).deliver
      rescue
        # If error, send by each
        receivers.each do |receiver|
          begin
            Mailer.version_compiled_notification(receiver, :version => self).deliver
          rescue
            next
          end
        end
      end

    end
  end

end

