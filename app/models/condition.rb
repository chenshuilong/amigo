class Condition < ActiveRecord::Base
  has_many :condition_files, :class_name => 'Condition', :foreign_key => "folder_id", dependent: :destroy
  has_many :condition_histories, :class_name => 'ConditionHistory', :foreign_key => "from_id", dependent: :destroy
  has_many :report_condition_histories, :class_name => 'ReportConditionHistory', :foreign_key => "from_id", dependent: :destroy
  belongs_to :folder, :class_name => 'Condition', :foreign_key => "folder_id"
  belongs_to :user
  has_one :report_condition, dependent: :destroy

  before_save :generate_conditon, :unless => :is_folder?
  after_save  :clear_cache_about_condition
  after_destroy :clear_cache_about_condition

  STATUS_ISSUE_STAR = 1
  STATUS_ISSUE_SYSTEM = 2
  STATUS_REPORT_STAR = 3
  STATUS_REPORT_SYSTEM = 4
  STATUS_REPORT_PREW = 5

  scope :star, -> {where("category = #{STATUS_ISSUE_STAR}")}
  scope :system, -> {where("category = #{STATUS_ISSUE_SYSTEM}")}
  scope :report_star, -> {where("category = #{STATUS_REPORT_STAR}")}
  scope :report_system, -> {where("category = #{STATUS_REPORT_SYSTEM}")}
  scope :root, -> {where(:folder_id => nil)}
  # scope :history, -> {where(:is_folder => false).order(:updated_at => :desc)}
  validates :name, :user_id, presence: true
  validates_presence_of :json, :unless => :is_folder?
  # validates :category, :numericality => { :equal_to => STATUS_ISSUE_STAR }, if: "!User.current.admin?"
  # validates :category, :numericality => { :equal_to => STATUS_REPORT_STAR }, if: "!User.current.admin?"
  validates :category, inclusion: {:in => [STATUS_ISSUE_STAR, STATUS_REPORT_STAR, STATUS_REPORT_PREW]}, if: "!User.current.admin?"
  validate :check_folder_id


  def self.column_order_last
    self.where("column_order <> ''").order(:updated_at => :desc).first
  end

  def is_personal?
    self.category == 1 || self.category == 3
  end

  def is_system?
    self.category == 2 || self.category == 4
  end

  # Analyze possible users in condition based on all numbers
  def possible_users
    ids = []
    ids = condition.scan(/\d+/) if condition.present?
    User.where(:id => ids)
  end

  private

  def check_folder_id
    return true if self.folder_id.nil?
    status = self.category == Condition.find(self.folder_id).category
    errors.add(:category_comparison, '类别与父级类别不一致！') unless status
  end

  def generate_conditon
    hash = JSON.parse(self.json)
    condition = hash.present? ? json_to_condition(hash) : nil
    self.condition = condition
  end

  def json_to_condition(json,relation=nil)
    condition = String.new
    json.each do |k,v|
      if v.is_a?(Hash)
        condition << json_to_condition(v, k[/\w+/])
      else
        head, body, foot = v[0], v[1].strip, v[2]
        foot_was = v[2]
        # Handle body and foot
        if foot.is_a?(Array)
          body = body == "<>" ? 'NOT IN' : 'IN'
          foot = '("' + foot*'","' + '")'
        elsif foot.nil?
          body = body == "<>" ? 'IS NOT' : 'IS'
          foot = "NULL"
        else
          foot = /LIKE/ === body ? "\"%#{foot}%\"" : "\"#{foot}\""
        end
        # return condition
        case head
        when /cf_/
          condition << <<~MYSQL
            ( issues.id in (select distinct issues.id from issues
              left join custom_values on custom_values.customized_id = issues.id
              where custom_values.custom_field_id = #{head[/\d+/]} AND custom_values.value #{body} #{foot})
            )
          MYSQL
        when /ls_user_id/
          condition << <<~MYSQL
            ( issues.id in (select distinct issues.id from issues
              left join journals on journals.journalized_id = issues.id
              where journals.user_id #{body} #{foot})
            )
          MYSQL
        when /ls_/
          condition << <<~MYSQL
            ( issues.id in (select distinct issues.id from issues
              left join journals on journals.journalized_id = issues.id
              left join journal_details on journal_details.journal_id = journals.id
              where (journal_details.prop_key = "#{head.gsub(/\Als_/, '')}" AND journal_details.old_value #{body} #{foot})
              OR issues.#{head.gsub(/\Als_/, '')} #{body} #{foot})
            )
          MYSQL
        when /issue_id/
          body = body == "<>" ? 'NOT IN' : 'IN'
          condition << "issues.id #{body} (#{foot_was.scan(/\d+/)*','})"
        when /watcher_id/
          condition << <<~MYSQL
            ( issues.id in (select distinct issues.id from issues
              left join watchers on watchers.watchable_id = issues.id
              where watchers.user_id #{body} #{foot})
            )
          MYSQL
        when /mokuai_name/
          ids = []
          foot_was.each { |f| ids += Mokuai.where(:name => f).pluck(:id)}
          condition << "issues.mokuai_name #{body} (#{ids*','})"
        when /dept_id/
          ids = foot_was.join("_")
          condition << "issues.assigned_to_id #{body} \"dept_#{ids}\""
        when /issue_note/
          body = /NOT/ === body ? 'NOT IN' : 'IN'
          condition << <<~MYSQL
            ( issues.id #{body} (select distinct issues.id from issues
              left join journals on journals.journalized_id = issues.id
              where journals.notes LIKE #{foot})
            )
          MYSQL
        when /author_group/
          ids = foot_was.join("_")
          condition << "issues.author_id #{body} \"group_#{ids}\""
        when Regexp.new(IssueRelation::TYPES.map(&:first).join("|"))
          body = /LIKE|=/ === body ? '=' : '!'
          condition << IssueQuery.new.sql_for_relations(head, body, [foot_was.to_i])
        else
          condition << "issues.#{head} #{body} #{foot}"
        end
      end
      condition << " #{relation} " unless json.keys.last == k
    end
    return "(#{condition})"
  end

  def clear_cache_about_condition
    $redis.hdel("issues/index.condition_lists", "system")        if is_system?
    $redis.hdel("issues/index.condition_lists", User.current.id) if is_personal?
  end

end
