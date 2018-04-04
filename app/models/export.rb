class Export < ActiveRecord::Base
  include QueriesHelper

  STORAGE_PATH  = Rails.root.join('files', 'tmp', 'exports')
  EXPORT_CATEGORY = {:issue => 1, :staff => 2}
  EXPORT_STATUS = {:queued => 1, :processing => 2, :completed => 3, :failed => 4}
  QUICKER_LINES = 3000
  serialize :options, Hash

  before_create :set_default_attr
  after_commit  :add_to_export_task, on: :create

  scope :mine, -> { where(:user_id => User.current.id) }
  scope :queue, -> { where(:status => EXPORT_STATUS[:queued]) }
  scope :undeleted, -> { where(:deleted => false) }
  scope :to_be_done, -> {undeleted.where(:status => EXPORT_STATUS.slice(:queued, :processing).values)}

  def download_file_name
    "#{name}.#{format}"
  end

  def file_path
    STORAGE_PATH.join(user_id.to_s, "#{disk_file}.#{format}")
  end

  def do_delete!
    update_column :deleted, true
  end

  def queued_before_self
    if lines.to_i > QUICKER_LINES
      Export.queue.undeleted.where("exports.lines > ? AND id <= ?", QUICKER_LINES, id).count
    else
      Export.queue.undeleted.where("exports.lines <= ? AND id <= ?", QUICKER_LINES, id).count
    end
  end

  def add_to_export_task
    case EXPORT_CATEGORY.invert[category]
      when :issue
        if lines.to_i > QUICKER_LINES
          IssueExportJob.perform_later(id)
        else
          unless self.deleted?
            begin # catch error
              quick
            rescue => e
              puts "Error occured, Export id: #{id}, reason: #{e}"
              self.update_column :status, EXPORT_STATUS[:failed]
            end
          end
        end
      when :staff
        export_staff
    end
  end

  def export_staff
    self.update_column :status, EXPORT_STATUS[:processing] # Export start

    begin
      users = User.export_staffs(self.options[:ids].join(','))
      ausers = []
      # 此处应该需要优化
      users.each { |user|
        if user.dept2.present?
          user.dept1 = user.parentNm
        elsif user.dept3.present?
          user.dept2 = user.parentNm
          user.dept1 = Dept.find_by_orgNo(user.parentNo).orgNm
        elsif user.dept4.present?
          user.dept3 = user.parentNm
          user.dept2 = Dept.find_by_orgNo(user.parentNo).orgNm
          user.dept1 = Dept.find_by_orgNo(user.parentNo).parent.orgNm
        elsif user.dept5.present?
          user.dept4 = user.parentNm
          user.dept3 = Dept.find_by_orgNo(user.parentNo).orgNm
          user.dept2 = Dept.find_by_orgNo(user.parentNo).parent.orgNm
          user.dept1 = Dept.find_by_orgNo(user.parentNo).parent.parent.orgNm
        elsif user.dept6.present?
          user.dept5 = user.parentNm
          user.dept4 = Dept.find_by_orgNo(user.parentNo).orgNm
          user.dept3 = Dept.find_by_orgNo(user.parentNo).parent.orgNm
          user.dept2 = Dept.find_by_orgNo(user.parentNo).parent.parent.orgNm
          user.dept1 = Dept.find_by_orgNo(user.parentNo).parent.parent.parent.orgNm
        elsif user.dept7.present?
          user.dept6 = user.parentNm
          user.dept5 = Dept.find_by_orgNo(user.parentNo).orgNm
          user.dept4 = Dept.find_by_orgNo(user.parentNo).parent.orgNm
          user.dept3 = Dept.find_by_orgNo(user.parentNo).parent.parent.orgNm
          user.dept2 = Dept.find_by_orgNo(user.parentNo).parent.parent.parent.orgNm
          user.dept1 = Dept.find_by_orgNo(user.parentNo).parent.parent.parent.parent.orgNm
        end
        ausers << user
      }
      time_start = Time.now
      # update lines of export files
      self.update_column :lines, users.length

      columns = {"dept1" => "一级部门", "dept2" => "二级部门",
                 "dept3" => "三级部门", "dept4" => "四级部门",
                 "dept5" => "五级部门", "dept6" => "六级部门",
                 "dept7" => "七级部门", "username" => "姓名"}
      file = $db.slave { ApplicationController.new.data_to_xlsx(ausers, columns) }
      file_path = self.file_path
      dirname = File.dirname(file_path)
      FileUtils.mkdir_p(dirname) unless Dir.exist?(dirname)

      if file.respond_to? :serialize
        file.serialize file_path
      else
        File.open(file_path, 'w+') { |f| f.write(file) }
      end

      self.update_columns(
          :status     => EXPORT_STATUS[:completed],
          :total_time => (Time.now - time_start).round,
          :file_size  => File.size(file_path)
      )

      file = nil # Clear memory
    rescue => e
      self.update_column :status, EXPORT_STATUS[:failed]
    end
  end

  def quick
    User.current = $db.slave { User.find(self.user_id) }
    opts   = self.options
    query  = IssueQuery.new opts[:query]
    params = opts[:params]
    export_ids = params[:export_ids]
    limit = $db.slave { Setting.issues_export_limit.to_i }
    offset = 0

    self.update_column :status, EXPORT_STATUS[:processing] # Export start
    time_start = Time.now

    if export_ids.present?
      export_ids = export_ids.split(",").reject(&:blank?)
      issues = $db.slave { Issue.where(:id => export_ids).order("FIELD(id, #{export_ids*','} )") }
    else
      issues = $db.slave {
        # User.current = User.find_by(:id => export.user_id)
        query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
                     :order   => opts[:order],
                     :offset  => offset,
                     :limit   => limit,
                     :reorder => opts[:reorder])
      }
    end

    # update lines of export files
    self.update_column :lines, issues.length

    klass = Class.new.extend(QueriesHelper)
    klass.class_eval do
      def self.issue_url(item)
        Rails.application.routes.url_helpers.issue_url item, :host => Setting.host_name
      end
    end

    file = $db.slave { klass.send("query_to_#{self.format}", issues, query, params[:csv]) }
    file_path = self.file_path
    dirname = File.dirname(file_path)
    FileUtils.mkdir_p(dirname) unless Dir.exist?(dirname)

    if file.respond_to? :serialize
      file.serialize file_path
    else
      File.open(file_path, 'w+') { |f| f.write(file) }
    end

    self.update_columns(
        :status     => EXPORT_STATUS[:completed],
        :total_time => (Time.now - time_start).round,
        :file_size  => File.size(file_path)
    )

    file = nil # Clear memory
  end

  private

  def set_default_attr
    self.status     ||= EXPORT_STATUS[:queued]
    self.user_id    ||= User.current.id
    self.disk_file  ||= SecureRandom.uuid
  end
end
